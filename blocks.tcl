# -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## blocked blob storage.
#
## blobs are split into mainly equal sized blocks which are then store
## in the actual backend, another blob store. It is expected that this
## reduces storage volume by finding and sharing identical blocks
## between files. The block store maintains its own state, first a
## mapping from blobs to its blocks and their order, and second, a
## per-block reference count to manage sharing in the presence of
## deletion.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require dbutil
package require sqlite3
package require blob
package require tcl::chan::cat ; # tcllib

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::blocks {
    superclass blob

    # # ## ### ##### ######## #############
    ## State

    variable myblocksize mylastbyte \
	sql_toblocks sql_clear sql_exists sql_size \
	sql_names_all sql_names sql_unshare sql_lost \
	sql_delete sql_extend sql_newblock sql_map \
	sql_hasblock sql_share

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {theblocksize backend database table} {
	set myblocksize $theblocksize
	set mylastbyte  [incr theblocksize -1]

	# Make backend and database available as a local command,
	# under a fixed name. No need for an instance variable and
	# resolution.
	interp alias {} [self namespace]::BACKEND {} $backend
	interp alias {} [self namespace]::DB      {} $database

	my InitializeSchema $table
	next
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    # add: blob --> ()
    method Enter {uuid blob} {
	DB transaction {
	    if {[my exists $uuid]} return

	    DB eval $sql_extend
	    set blobid [DB last_insert_rowid]
	    set blkno  0

	    set n [string length $blob]
	    if {!$n} return

	    # split into blocks.
	    set s 0
	    set e $mylastbyte
	    
	    while {1} {
		# store blocks, remember blocks, manage refcounts.
		# remember blob to block map.
		set block   [string range $blob $s $e]
		set blkuuid [BACKEND add $block]

		if {[DB exists $sql_hasblock]} {
		    set blkid [DB eval $sql_hasblock]
		    DB eval $sql_share
		} else {
		    DB eval $sql_newblock
		    set blkid [DB last_insert_rowid]
		}

		# add block to blob map.
		DB eval $sql_map
		incr blkno

		if {$e > $n} break
		incr s $myblocksize
		incr e $myblocksize
	    }
	}
	return
    }

    # put: path --> ()
    method EnterPath {uuid path} {
	DB transaction {
	    if {[my exists $uuid]} return
	    my Enter $uuid [my Cat $path]
	}
	return
    }

    # retrieve: uuid --> blob
    method retrieve {uuid} {
	# pull blocks for blob as strings, assemble into string.
	DB transaction {
	    my Validate $uuid
	    set data {}
	    DB eval $sql_toblocks {
		lappend data [BACKEND retrieve $blkuuid]
	    }
	    return $data
	}
    }

    # channel: uuid --> channel
    method channel {uuid} {
	# pull blocks for blob, as channel, assemble into concat
	# channel
	DB transaction {
	    my Validate $uuid
	    set parts {}
	    DB eval $sql_toblocks {
		lappend parts [BACKEND channel $blkuuid]
	    }
	    return [tcl::chan::cat {*}$parts]
	}
    }

    # names () -> list(uuid)
    method Names {{pattern *}} {
	if {$pattern eq "*"} {
	    DB transaction {
		return [DB eval $sql_names_all]
	    }
	} else {
	    DB transaction {
		return [DB eval $sql_names]
	    }
	}
    }

    # exists: string -> boolean
    method exists {uuid} {
	DB transaction {
	    DB exists $sql_exists
	}
    }

    # size () -> integer
    method size {} {
	variable size
	if {[info exists size]} { return $size }
	DB transaction {
	    set size [DB eval $sql_size]
	}
	# implied return
    }

    # clear () -> ()
    method clear {} {
	# NOTE !! assumes that backend is not shared with other blocks
	# stores, or even used as its own blob store.
	variable size ; unset -nocomplain size
	DB transaction {
	    DB eval $sql_clear
	    BACKEND clear
	}
	return
    }

    # delete: uuid -> ()
    method delete {uuid} {
	# pull block list, manage refcounts.
	# delete blocks not used anymore.
	DB transaction {
	    DB eval $sql_unshare
	    DB eval $sql_lost {
		BACKEND delete $blkuuid
	    }
	    DB eval $sql_delete
	}
	return
    }

    # # ## ### ##### ######## #############

    method Validate {uuid} {
	if {[my exists $uuid]} return
	my Error "Expected uuid, got \"$uuid\"" \
	    BAD UUID $uuid
    }

    # # ## ### ##### ######## #############
    ## Internals

    method InitializeSchema {table} {
	lappend map <<table>> $table

	set fqndb [self namespace]::DB

	if {![dbutil initialize-schema $fqndb reason ${table}_blob {{
	    -- list of known blobs
	    id   INTEGER PRIMARY KEY AUTOINCREMENT,
	    uuid TEXT    UNIQUE      NOT NULL
	} {
	    {id   INTEGER 0 {} 1}
	    {uuid TEXT    1 {} 0}
	}}] || ![dbutil initialize-schema $fqndb reason ${table}_block {{
	    -- list of known blocks with their own uuid and refcount for sharing mgmt.
	    id       INTEGER PRIMARY KEY AUTOINCREMENT,
	    uuid     TEXT    UNIQUE      NOT NULL,
	    refcount INTEGER             NOT NULL
	    -- index on refcount --
	} {
	    {id       INTEGER 0 {} 1}
	    {uuid     TEXT    1 {} 0}
	    {refcount INTEGER 0 {} 0}
	}}] || ![dbutil initialize-schema $fqndb reason ${table}_map {{
	    -- map from blob to blocks, with sequential block order
	    blobid INTEGER NOT NULL, -- REFERENCES ${table}_blob,
	    blkno  INTEGER NOT NULL,
	    blkid  INTEGER NOT NULL, -- REFERENCES ${table}_block,
	    PRIMARY KEY (blobid, blkno)
	} {
	    {blobid INTEGER 0 {} 1}
	    {blkno  INTEGER 0 {} 1}
	    {blkid  INTEGER 0 {} 0}
	}}]} {
	    my Error $reason BAD SCHEMA
	}

	# Generate the custom sql commands.
	my Def sql_extend   { INSERT INTO "<<table>>_blob"  VALUES (NULL, :uuid) }
	my Def sql_newblock { INSERT INTO "<<table>>_block" VALUES (NULL, :blkuuid, 0) }
	my Def sql_map      { INSERT INTO "<<table>>_map"   VALUES (:blobid, :blkno, :blkid) }
	my Def sql_hasblock { SELECT id FROM "<<table>>_block" WHERE uuid = :blkuuid }
	my Def sql_share {
	    UPDATE "<<table>>_block"
	    SET    refcount = refcount + 1
	    WHERE  id = :blkid
	}

	my Def sql_toblocks {
	    SELECT B.uuid AS blkuuid
	    FROM "<<table>>_block" AS B,
	         "<<table>>_map"   AS M,
	         "<<table>>_blob"  AS X
	    WHERE X.uuid  = :uuid
	    AND   X.id    = M.blobid
	    AND   M.blkid = B.id
	    ORDER BY M.blkno ASC
	}

	my Def sql_clear     {
	    DELETE FROM "<<table>>_blob";
	    DELETE FROM "<<table>>_block";
	    DELETE FROM "<<table>>_map"
	}
	my Def sql_exists    { SELECT uuid     FROM "<<table>>_blob" WHERE uuid = :uuid }
	my Def sql_names_all { SELECT uuid     FROM "<<table>>_blob" }
	my Def sql_names     { SELECT uuid     FROM "<<table>>_blob" WHERE uuid GLOB :pattern }
	my Def sql_size      { SELECT count(*) FROM "<<table>>_blob" }

	my Def sql_unshare {
	    UPDATE "<<table>>_block"
	    SET    refcount = refcount - 1
	    WHERE  id IN ( SELECT blkid
			   FROM   "<<table>>_map"
			   WHERE  blobid = ( SELECT id
					     FROM   "<<table>>_blob"
					     WHERE  uuid = :uuid ))
	}
	my Def sql_lost {
	    SELECT uuid AS blkuuid FROM "<<table>>_block" WHERE refcount = 0
	}
	my Def sql_delete {
	    DELETE FROM "<<table>>_block" WHERE refcount = 0;
	    DELETE FROM "<<table>>_blob"  WHERE uuid = :uuid
	}
	return
    }

    method Def {var sql} {
	upvar 1 map map
	set $var [string map $map $sql]
	return
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob::blocks 0
return
