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
package require blob
package require tcl::chan::string ; # tcllib

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::blocks {
    superclass blob

    # # ## ### ##### ######## #############
    ## State

    variable myblocksize
    # mystore: dict (uuid -> blob)

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {theblocksize backend database table} {
	set myblocksize $theblocksize

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
	if {[... exists ... $uuid]} return
	# split into blocks, store blocks, remember blocks, manage refcounts.
	# remember blob to block map.
	return
    }

    # put: path --> ()
    method EnterPath {uuid path} {
	if {[... exists ... $uuid]} return
	my Enter $uuid [my Cat $path]
	return
    }

    # retrieve: uuid --> blob
    method retrieve {uuid} {
	my Validate $uuid
	# pull blocks for blob as strings, assemble into string.
	return ...
    }

    # channel: uuid --> channel
    method channel {uuid} {
	my Validate $uuid
	# pull blocks for blob, as channel, assemble into concat
	# channel
	return ... 
    }

    # names () -> list(uuid)
    method Names {{pattern *}} {
	...
    }

    # exists: string -> boolean
    method exists {uuid} {
	...
    }

    # size () -> integer
    method size {} {
	...
    }

    # clear () -> ()
    method clear {} {
	# NOTE !! assumes that backend is not shared with other blocks
	# stores, or even used as its own blob store.

	BACKEND clear
	... database maps clear
	return
    }

    # delete: uuid -> ()
    method delete {uuid} {
	# pull block list, manage refcounts.
	# delete blocks not used anymore.
	return
    }

    # # ## ### ##### ######## #############

    method Validate {uuid} {


	if {[... exists ... $uuid]} return
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
	    uuid TEXT    UNIQUE      NOT NULL,
	} {
	    {id   INTEGER 0 {} 1}
	    {uuid TEXT    1 {} 0}
	}}] && ![dbutil initialize-schema $fqndb reason ${table}_block {{
	    -- list of known blocks with their own uuid and refcount for sharing mgmt.
	    id       INTEGER PRIMARY KEY AUTOINCREMENT,
	    uuid     TEXT    UNIQUE      NOT NULL,
	    refcount INTEGER             NOT NULL
	} {
	    {id       INTEGER 0 {} 1}
	    {uuid     TEXT    1 {} 0}
	    {refcount INTEGER 0 {} 0}
	}}] && ![dbutil initialize-schema $fqndb reason ${table}_map {{
	    -- map from blob to blocks, with sequential block order
	    blobid INTEGER NOT NULL, -- REFERENCES ${table}_blob,
	    blkno  INTEGER NOT NULL,
	    blkid  INTEGER NOT NULL, -- REFERENCES ${table}_block,
	    PRIMARY KEY (id, ord)
	} {
	    {blobid INTEGER 0 {} 1}
	    {blkno  INTEGER 0 {} 1}
	    {blkid  INTEGER 0 {} 0}
	}}]} {
	    my Error $reason BAD SCHEMA
	}

	# Generate the custom sql commands.
	#my Def sql_extend    { INSERT          INTO "<<table>>" VALUES (NULL, :uuid, @blob) }
	#my Def sql_clear     { DELETE          FROM "<<table>>" }
	#my Def sql_delete    { DELETE          FROM "<<table>>" WHERE uuid = :uuid }
	#my Def sql_toblob    { SELECT data     FROM "<<table>>" WHERE uuid = :uuid }
	#my Def sql_toid      { SELECT id       FROM "<<table>>" WHERE uuid = :uuid }
	#my Def sql_names_all { SELECT uuid     FROM "<<table>>" }
	#my Def sql_names     { SELECT uuid     FROM "<<table>>" WHERE uuid GLOB :pattern }
	#my Def sql_size      { SELECT count(*) FROM "<<table>>" }
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
package provide blob::memory 0
return
