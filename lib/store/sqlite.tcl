# -*- tcl -*-
## (c) 2013-2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## sqlite based blob storage.

# @@ Meta Begin
# Package blob::sqlite 1
# Meta author      {Andreas Kupries}
# Meta category    Blob storage, database
# Meta description Store blobs in sqlite databases
# Meta location    http:/core.tcl.tk/akupries/blob
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     blob
# Meta require     dbutil
# Meta require     debug
# Meta require     debug::caller
# Meta require     sha1
# Meta require     sqlite3
# Meta subject     {blob storage} storage sqlite
# Meta subject     database
# Meta summary     Blob storage
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require blob
package require dbutil
package require sha1 2
package require sqlite3
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define blob/sqlite
debug level  blob/sqlite
#debug prefix blob/sqlite {[debug caller] | }
debug prefix blob/sqlite {} ;# No prefix, arguments can be large

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::sqlite {
    superclass blob

    # # ## ### ##### ######## #############
    ## State

    variable mytable \
	sql_extend sql_clear sql_delete \
	sql_toblob sql_toid sql_names sql_size \
	sql_names_all
    # Name of the database table used for storage.
    # plus the sql commands to access it.

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {database table} {
	debug.blob/sqlite {}
	# Make the database available as a local command, under a
	# fixed name. No need for an instance variable and resolution.
	interp alias {} [self namespace]::DB {} $database

	my InitializeSchema $table
	set mytable $table

	next
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    method PreferedPut {} { return path }

    # put-string :- EnterString: uuid, blob --> ()
    method EnterString {uuid blob} {
	DB transaction {
	    if {![DB exists $sql_toblob]} {
		variable size
		if {[info exists size]} { incr size }
		DB eval $sql_extend
	    }
	}
	return
    }

    # put-file :- EnterFile: uuid, path --> ()
    method EnterFile {uuid path} {
	DB transaction {
	    if {![DB exists $sql_toblob]} {
		variable size
		set blob [my Cat $path]
		if {[info exists size]} { incr size }
		DB eval $sql_extend
	    }
	}
	return
    }

    # get-string: uuid --> blob
    method get-string {uuid} {
	DB transaction {
	    my Validate $uuid
	    return [DB onecolumn $sql_toblob]
	}
    }

    # get-channel: uuid --> channel
    method get-channel {uuid} {
	DB transaction {
	    my Validate $uuid
	    set rid [DB onecolumn $sql_toid]
	    DB incrblob -readonly $mytable data $rid
	}
    }

    # get-file: inherited, via get-string

    # names :- Names: (?pattern?) -> list(uuid)
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

    # clear: () -> ()
    # Remove all known mappings.
    method clear {} {
	variable size ; unset -nocomplain size
	DB transaction {
	    DB eval $sql_clear
	}
	return
    }

    # delete: uuid -> ()
    method delete {uuid} {
	DB transaction {
	    DB eval $sql_delete
	}
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
	my Def sql_extend    { INSERT          INTO "<<table>>" VALUES (NULL, :uuid, @blob) }
	my Def sql_clear     { DELETE          FROM "<<table>>" }
	my Def sql_delete    { DELETE          FROM "<<table>>" WHERE uuid = :uuid }
	my Def sql_toblob    { SELECT data     FROM "<<table>>" WHERE uuid = :uuid }
	my Def sql_toid      { SELECT id       FROM "<<table>>" WHERE uuid = :uuid }
	my Def sql_names_all { SELECT uuid     FROM "<<table>>" }
	my Def sql_names     { SELECT uuid     FROM "<<table>>" WHERE uuid GLOB :pattern }
	my Def sql_size      { SELECT count(*) FROM "<<table>>" }

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
