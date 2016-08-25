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

proc ::blob::table::iter {db table vtype otype collation} {
    debug.blob/table {}
    # Iterator content. Sibling to the blob store table.
    # - id   - is PK --> blob table -- uuid is UNIQUE indexed
    # - pval - indexed, easy sorting

    # vtype is the type of the values in the iteration table.
    # otype is the type of the values we are ordering by.

    # When ordering is done on the values in the iteration table they
    # are identical. However if the values for the ordering are stored
    # in a separate table (See sqlite.tcl: sidecar), then they are
    # not. In that case vtype is about the FK references to the
    # sidecar in the iteration table, and otype to the actual type of
    # the values, and thus also which state table to use. The cursor
    # location uses the actual value from the sidecar to make the
    # comparisons in the sql commands easier.

    lappend map <<vtype>> $vtype
    lappend map <<otype>> $otype

    if {$collation ne {}} {
	lappend map <<coll>> "COLLATE $collation"
    } else {
	lappend map <<coll>> ""
    }

    if {![dbutil initialize-schema $db reason $table \
	      [string map $map {{
		    id   INTEGER PRIMARY KEY -- <=> (blob-table).id
		  , pval <<vtype>> NOT NULL <<coll>>
	      } {
		  {id   INTEGER   0 {} 1}
		  {pval <<vtype>> 1 {} 0}
	      } {
		  pval
	      }}]]} {
	Error $reason BAD SCHEMA
    }

    # Iterator status table. All iterators with the same type of key
    # share a state table. The different states are separated by the
    # <itertable>
    if {![dbutil initialize-schema $db reason blobiter_${otype}_state \
	      [string map $map {{
		    id          INTEGER PRIMARY KEY AUTOINCREMENT
		  , who         TEXT NOT NULL UNIQUE
		  , increasing  INTEGER NOT NULL
		  , cursor_code INTEGER NOT NULL
		  , cursor_pval <<otype>>
		  , cursor_uuid TEXT
	      } {
		  {id          INTEGER   0 {} 1}
		  {who         TEXT      1 {} 0}
		  {increasing  INTEGER   1 {} 0}
		  {cursor_code INTEGER   1 {} 0}
		  {cursor_pval <<otype>> 0 {} 0}
		  {cursor_uuid TEXT      0 {} 0}
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
	INTO blobiter_<<otype>>_state
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
