# -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## sqlite based blob storage.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require blob
package require dbutil
package require sha1 2
package require sqlite3

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::sqlite {
    superclass blob

    # # ## ### ##### ######## #############
    ## State

    variable mytable \
	sql_extend sql_clear sql_toblob sql_toid sql_names sql_size
    # Name of the database table used for storage.
    # plus the sql commands to access it.

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {database table} {
	# Make the database available as a local command, under a
	# fixed name. No need for an instance variable and resolution.
	interp alias {} [self namespace]::DB {} $database

	my InitializeSchema $table
	set mytable $table
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    # add: blob --> uuid
    method add {blob} {
	set uuid [my Uuid.blob $blob]
	DB transaction {
	    if {![DB exists $sql_toblob]} {
		variable size
		if {[info exists size]} { incr size }
		DB eval $sql_extend
	    }
	}
	return $uuid
    }

    # put: path --> uuid
    method put {path} {
	set uuid [my Uuid.path $path]
	DB transaction {
	    if {![DB exists $sql_toblob]} {
		variable size
		set blob [my Cat $path]
		if {[info exists size]} { incr size }
		DB eval $sql_extend
	    }
	}
	return $uuid
    }

    # retrieve: uuid --> blob
    method retrieve {uuid} {
	DB transaction {
	    if {![DB exists $sql_toblob]} {
		my Error "Expected uuid, got \"$uuid\"" \
		    BAD UUID $uuid
	    }
	    return [DB onecolumn $sql_toblob]
	}
    }

    # retrieve: uuid --> channel
    method channel {uuid} {
	DB transaction {
	    if {![DB exists $sql_toblob]} {
		my Error "Expected uuid, got \"$uuid\"" \
		    BAD UUID $uuid
	    }
	    set rid [DB onecolumn $sql_toid]
	    DB incrblob -readonly $mytable data $rid
	}
    }



    # names () -> list(uuid)
    method names {} {
	DB transaction {
	    return [DB eval $sql_names]
	}
    }

    # exists: uuid -> boolean
    method exists {uuid} {
	DB transaction {
	    DB exists $sql_toblob
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
    # Remove all known mappings.
    method clear {} {
	variable size ; unset -nocomplain size
	DB transaction {
	    DB eval $sql_clear
	}
	return
    }

    # # ## ### ##### ######## #############
    ## Internals

    method InitializeSchema {table} {
	lappend map <<table>> $table

	set fqndb [self namespace]::DB

	if {![dbutil initialize-schema $fqndb reason $table {{
	    id   INTEGER PRIMARY KEY AUTOINCREMENT,
	    uuid TEXT    UNIQUE      NOT NULL,
	    data BLOB
	} {
	    {id   INTEGER 0 {} 1}
	    {uuid TEXT    1 {} 0}
	    {data BLOB    0 {} 0}
	}}]} {
	    my Error $reason BAD SCHEMA
	}

	# Generate the custom sql commands.
	my Def sql_extend   { INSERT          INTO "<<table>>" VALUES (NULL, :uuid, @blob) }
	my Def sql_clear    { DELETE          FROM "<<table>>" }
	my Def sql_toblob   { SELECT data     FROM "<<table>>" WHERE uuid = :uuid }
	my Def sql_toid     { SELECT id       FROM "<<table>>" WHERE uuid = :uuid }
	my Def sql_names    { SELECT uuid     FROM "<<table>>" }
	my Def sql_size     { SELECT count(*) FROM "<<table>>" }

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
package provide blob::sqlite 0
return
