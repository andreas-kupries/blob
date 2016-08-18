# -*- tcl -*-
## (c) 2013-2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## sqlite based blob storage - shared code

# @@ Meta Begin
# Package blob::table 1
# Meta author      {Andreas Kupries}
# Meta category    Blob storage, database, table utilities
# Meta description Store blobs in sqlite database, common code
# Meta location    http:/core.tcl.tk/akupries/blob
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     dbutil
# Meta require     debug
# Meta require     debug::caller
# Meta subject     {blob storage} storage sqlite database
# Meta summary     Blob storage
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define blob/table
debug level  blob/table
debug prefix blob/table {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Implementation

namespace eval blob::table {}

# # ## ### ##### ######## ############# #####################
## Table definitions for stores and iterators
#
# Store:          (id, uuid, data) -- id unique, uuid unique
#                  ^v
# Iterator Data:  (id, key)        -- id unique & fk store, key indexed
# Iterator State: (id, table, code, key, uuid)

proc ::blob::table::store {db table} {
    debug.blob/table {}

    if {![dbutil initialize-schema $db reason $table {{
	  id   INTEGER PRIMARY KEY AUTOINCREMENT
	, uuid TEXT    UNIQUE      NOT NULL
	, data BLOB
    } {
	{id   INTEGER 0 {} 1}
	{uuid TEXT    1 {} 0}
	{data BLOB    0 {} 0}
    }}]} {
	Error $reason BAD SCHEMA
    }
    return
}

proc ::blob::table::iter {db table type} {
    debug.blob/table {}
    # Iterator content. Sibling to the blob store table.
    # - id is PK --> blob table -- uuid is UNIQUE indexed
    # - key - indexed

    lappend map <<type>> $type

    if {![dbutil initialize-schema $db reason $table \
	      [string map $map {{
		    id  INTEGER PRIMARY KEY -- <=> (blob-table).id
		  , key <<type>> NOT NULL
	      } {
		  {id  INTEGER  0 {} 1}
		  {key <<type>> 1 {} 0}
	      } {
		  key
	      }}]]} {
	Error $reason BAD SCHEMA
    }

    # Iterator status table. All iterators with the same type of key
    # share a state table. The different states are separated by the
    # <itertable>
    if {![dbutil initialize-schema $db reason blobiter_${type}_state \
	      [string map $map {{
		    id          INTEGER PRIMARY KEY AUTOINCREMENT
		  , who         TEXT NOT NULL UNIQUE
		  , increasing  INTEGER NOT NULL
		  , cursor_code INTEGER NOT NULL
		  , cursor_key  <<type>>
		  , cursor_uuid TEXT
	      } {
		  {id          INTEGER  0 {} 1}
		  {who         TEXT     1 {} 0}
		  {increasing  INTEGER  1 {} 0}
		  {cursor_code INTEGER  1 {} 0}
		  {cursor_key  <<type>> 0 {} 0}
		  {cursor_uuid TEXT     0 {} 0}
	      }}]]} {
	Error $reason BAD SCHEMA
    }

    # Fill the state table with the initial iterator setup. This
    # ensures that everything else can assume that this row
    # exists. The uniqueness of the iterator table name also ensures
    # that construction fails when trying to make multiple iterators
    # attach to the same tables.
    $db eval [string map $map {
	INSERT
	INTO blobiter_<<type>>_state
	VALUES (NULL, :table, 1, 1, NULL, NULL)
    }]
    return
}

proc blob::table::Error {text args} {
    debug.blob/table {}
    return -code error -errorcode [list BLOB {*}$args] $text
}

# # ## ### ##### ######## ############# #####################
package provide blob::table 0
return
