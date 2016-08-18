# -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## sqlite-stored blob iterators.

# @@ Meta Begin
# Package blob::iter::sqlite 1
# Meta author      {Andreas Kupries}
# Meta category    Blob iteration, sqlite
# Meta description Keep blob iterator in an sqlite database
# Meta location    http:/core.tcl.tk/akupries/blob
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     debug
# Meta require     debug::caller
# Meta require     blob::iter
# Meta subject     {blob iterator} iterator sqlite
# Meta summary     Blob iterator
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require sqlite3
package require blob::iter
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define blob/iter/sqlite
debug level  blob/iter/sqlite
debug prefix blob/iter/sqlite {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::iter::sqlite {
    superclass blob::iter

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {db table itertable {type TEXT}} {
	debug.blob/iter/sqlite {}

	# Make the database available as a local command, under a
	# fixed name. No need for an instance variable and resolution.
	interp alias {} [self namespace]::DB {} $db

	# Configure the sql commands with the tables to use, and the
	# type of the key column.
	my InitializeSchema $table $itertable $type
	my LoadState
	next
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    # Add: (uuid key) --> ()
    method Add {uuid key} {
	debug.blob/iter/sqlite {}
	DB transaction {
	    DB eval $sql_add
	}
	return
    }

    # remove: (uuid) --> ()
    method Remove {uuid} {
	debug.blob/iter/sqlite {}
	DB transaction {
	    DB eval $sql_remove
	}
	# Note! No need to update the saved cursor location.  The
	# sql_forward/backward commands automatically take the
	# elements before/after the cursor, even if the cursor itself
	# is not an element of the table anymore. The LIMIT clause
	# automatically stops retrieval when we have enough data.
	#
	# This is in contrast to the "memory" iterator which has to
	# adjust the position because slicing is by direct access via
	# offsets, which need compensation when elements go away.

	debug.blob/iter/sqlite {/done}
	return
    }

    # clear: () --> ()
    method clear {} {
	debug.blob/iter/sqlite {}
	DB transaction {
	    set myincreasing 1
	    my reset
	    DB eval $sql_clear
	}
	return
    }

    # # ## ### ##### ######## #############

    # reset: () -> ()
    method reset {} {
	debug.blob/iter/sqlite {}
	set mycode       1
	set mykey        {}
	set myuuid       {}
	my SaveState
	return
    }

    # reverse:  () -> ()
    method reverse {} {
	debug.blob/iter/sqlite {}
	set myincreasing [expr {1-$myincreasing}]
	my SaveState
	return
    }

    # Expected interactions next, previous, and at:
    #
    # Show next:
    # - next, then at, and repeated
    # Show previous
    # - at, then previous, and repeated

    # next: length --> bool
    method next {n} {
	debug.blob/iter/sqlite {}
	my ValidatePosInt $n STEP

	if {![my CursorLocation]} {
	    my ToBoundary end
	    return false
	}

	# Step forward (virtual), physical step direction is given by
	# the chosen ordering.
	if {$myincreasing} {
	    DB transaction {
		DB eval $sql_next {
		    incr count
		    # New location is stored automatically, see sql definition
		}
	    }
	} else {
	    DB transaction {
		DB eval $sql_previous {
		    incr count
		    # New location is stored automatically, see sql definition
		}
	    }
	}
	if {$count < $n} {
	    # Got less than requested, stepped over boundary
	    my ToBoundary end
	    return false
	}

	# Persist new location
	set mycode 2
	my SaveState
	return true
    }

    # previous: length --> bool
    method previous {n} {
	debug.blob/iter/sqlite {}
	my ValidatePosInt $n STEP

	# Like next, with next and previous swapped.

	if {![my CursorLocation]} {
	    my ToBoundary start
	    return false
	}

	# Step backward (virtual), physical step direction is given by
	# the chosen ordering.
	if {$myincreasing} {
	    DB transaction {
		DB eval $sql_previous {
		    incr count
		    # New location is stored automatically, see sql definition
		}
	    }
	} else {
	    DB transaction {
		DB eval $sql_next {
		    incr count
		    # New location is stored automatically, see sql definition
		}
	    }
	}
	if {$count < $n} {
	    # Got less than requested, stepped over boundary
	    my ToBoundary start
	    return false
	}

	# Persist new location
	set mycode 2
	my SaveState
	return true
    }

    # to: pair('start',{})          --> ()
    #     pair('end',{})
    #     pair('at',pair(key,uuid))
    method to {location} {
	debug.blob/iter/sqlite {}

	if {[llength $location] != 2} {
	    my Error "Bad location \"$location\", expected list of 2 elements" \
		INVALID LOCATION SYNTAX
	}

	set type [lindex $location 0]
	switch -exact -- $type {
	    at {
		lassign [lindex $location 1] key uuid
		set has [DB eval $sql_has]
		if {!$has} {
		    my Error "Bad location \"$location\", not found" \
			INVALID LOCATION UNKNOWN
		}
		set mycode 2
		set mykey  $key
		set myuuid $uuid
	    }
	    start - end {
		my ToBoundary $type no
	    }
	    default {
		my Error "Bad location type \"$type\", expected at, end, or start" \
		    INVALID LOCATION TYPE
	    }
	}

	my SaveState
	return
    }

    # direction! (string) -> ()
    # __Inherited__ TODO: Check if this can be done better locally with direct access

    # data!: (list(tuple(key,uuid)) --> ()
    # __Inherited__ TODO: Check if this can be done better locally with direct access
    #               Single loop, validate while entering, error is rollback, undo.

    # # ## ### ##### ######## #############

    # exists: (uuid) -> bool
    method exists {uuid} {
	debug.blob/iter/sqlite {}
	DB transaction {
	    set found [DB eval $sql_exists]
	}
	debug.blob/iter/sqlite {==> $found}
	return $found
    }

    # size: () --> int
    method size {} {
	debug.blob/iter/sqlite {}
	DB transaction {
	    set size [DB eval $sql_size]
	}
	debug.blob/iter/sqlite {==> $size}
	return $size
    }

    # at: length --> list(tuple(key,uuid))
    method at {n} {
	debug.blob/iter/sqlite {}
	my ValidatePosInt $n SIZE

	if {![my CursorLocation]} {
	    # Return nothing if we have no proper location.
	    return {}
	}

	#my /SHOW

	# TODO: future optimization - Step one further than requested to have
	# the next cursor location ready for 'next' (or 'previous'(decreasing)).

	set slice {}
	if {$myincreasing} {
	    DB transaction {
		DB eval $sql_forward {
		    lappend slice [list $uuid $key]
		}
	    }
	} else {
	    DB transaction {
		DB eval $sql_backward {
		    lappend slice [list $uuid $key]
		}
	    }
	}
	return $slice
    }

    # direction: () -> string
    method direction {} {
	debug.blob/iter/sqlite {}
	set dir [expr {$myincreasing
		       ? "increasing"
		       : "decreasing"}]
	debug.blob/iter/sqlite {==> $dir}
	return $dir
    }

    # location: () -> tuple(key,uuid)
    method location {} {
	debug.blob/iter/sqlite {@l:($mycode ($mykey $myuuid))}

	switch -exact -- $mycode {
	    1 { set loc {start {}} }
	    3 { set loc {end {}} }
	    2 { set loc [list at [list $mykey $myuuid]] }
	}

	debug.blob/iter/sqlite {==> ($loc)}
	return $loc
    }

    # data: () -> list(tuple(uuid,key))
    method data {} {
	debug.blob/iter/sqlite {}
	set r {}
	DB transaction {
	    DB eval $sql_data {
		lappend r [list $uuid $key]
	    }
	}
	return $r
    }

    # # ## ### ##### ######## #############
    ## State

    # myincreasing - {0,1} - Sort order
    # mycode       - {1,2,3} - Cursor state
    #                1 = start = cursor at virtual start, ignore key/uuid
    #                2 = el    = cursor at specific key/uuid
    #                3 = end   = cursor at virtual end, ignore key/uuid
    # mykey        - 
    # myuuid       - 

    # Configuration:
    variable \
	myincreasing mycode mykey myuuid \
	sql_add         \
	sql_remove      \
	sql_clear       \
	sql_reset_state \
	sql_load_state  \
	sql_save_state  \
	sql_data        \
	sql_add_bulk    \
	sql_exists      \
	sql_has         \
	sql_size        \
	sql_forward     \
	sql_backward    \
	sql_min_entry   \
	sql_max_entry   \
	sql_next        \
	sql_previous

    # # ## ### ##### ######## #############
    # Internal helper methods

    method ToBoundary {s {save yes}} {
	debug.blob/iter/sqlite {}
	switch -exact -- $s {
	    start { set mycode 1 }
	    end   { set mycode 3 }
	    default {
		my Error "Internal use of bad boundary value \"$s\"" INTERNAL BAD BOUNDARY
	    }
	}
	if {$save} { my SaveState }
	return
    }

    method CursorLocation {} {
	debug.blob/iter/sqlite {}
	switch -exact -- $mycode$myincreasing {
	    11 - 30 {
		# start/increasing <=> end/decreasing <=> min entry
		DB transaction {
		    if {![my size]} { return false }
		    set pos [DB eval $sql_min_entry]
		}
	    }
	    21 - 20 {
		# At an actual position, nothing to do.
		return true
	    }
	    31 - 10 {
		# end/increasing <=> start/decreasing <=> max entry
		DB transaction {
		    if {![my size]} { return false }
		    set pos [DB eval $sql_max_entry]
		}
	    }
	}

	set mycode 2
	lassign $pos mykey myuuid
	my SaveState
	return true
    }

    method LoadState {} {
	debug.blob/iter/sqlite {}
	set myincreasing 1
	set mycode       1
	set mykey        {}
	set myuuid       {}
	DB transaction {
	    DB eval $sql_load_state
	}
	return
    }

    method SaveState {} {
	debug.blob/iter/sqlite {}
	DB transaction {
	    DB eval $sql_save_state
	}
	return
    }

    method InitializeSchema {table itertable type} {
	debug.blob/iter/sqlite {}
	lappend map <<table>> $table
	lappend map <<iter>>  $itertable
	lappend map <<type>>  $type

	set fqndb [self namespace]::DB

	### ... Same as in store/sqlite.tcl ...
	# Move into a shared base class
	if {![dbutil initialize-schema $fqndb reason $table {{
	      id   INTEGER PRIMARY KEY AUTOINCREMENT
	    , uuid TEXT    UNIQUE      NOT NULL
	    , data BLOB
	} {
	    {id   INTEGER 0 {} 1}
	    {uuid TEXT    1 {} 0}
	    {data BLOB    0 {} 0}
	}}]} {
	    my Error $reason BAD SCHEMA
	}

	# Iterator table, sibling to the blob table.
	# - id is PK --> blob table -- uuid is UNIQUE indexed
	# - key - indexed
	if {![dbutil initialize-schema $fqndb reason $itertable \
		  [string map $map {{
		        id  INTEGER PRIMARY KEY -- <=> table.id
		      , key <<type>> NOT NULL
		  } {
		      {id  INTEGER  0 {} 1}
		      {key <<type>> 1 {} 0}
		  } {
		      key
		  }}]]} {
	    my Error $reason BAD SCHEMA
	}

	# Iterator status table. All iterators with the same type of
	# key share a state table. The different states are separated
	# by the <itertable>
	if {![dbutil initialize-schema $fqndb reason blobiter_${type}_state \
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
	    my Error $reason BAD SCHEMA
	}

	# Fill the state table with the initial iterator setup. This
	# ensures that everything else can assume that this row
	# exists. The uniqueness of the iterator table name also
	# ensures that construction fails when trying to make multiple
	# iterators attach to the same tables.
	DB eval [string map $map {
	    INSERT
	    INTO blobiter_<<type>>_state
	    VALUES (NULL, :itertable, 1, 1, NULL, NULL)
	}]

	# Generate the custom sql commands.
	# . add entry to interator
	# . remove entry from iterator
	# . clear iterator
	#
	# . clear iterator state
	# . load iterator state
	# . write iterator state
	#
	# . bulk read iterator content
	# . <bulk extend iterator ?!>
	#
	# . test uuid for existence
	# . test uuid+key for existence
	# . determine size of iterator
	# . read slice forward
	# . read slice backward
	#
	# x Get cursor start
	# x Get cursor end
	# x Move cursor forward
	# x Move cursor backward
	#
	# Note: The iterator uses the blob <<table>> to find relevant UUIDs,
	#       and thus avoiding the need for saving its own duplicate.

	my Def sql_add {
	    INSERT INTO <<iter>>
	    VALUES ((SELECT id
		     FROM <<table>>
		     WHERE uuid = :uuid),
		    :key)
	}

	my Def sql_remove {
	    DELETE
	    FROM <<iter>>
	    WHERE id = (SELECT id
			FROM <<table>>
			WHERE uuid = :uuid)
	}

	my Def sql_clear {
	    DELETE FROM "<<iter>>"
	}

	my Def sql_reset_state {
	    UPDATE blobiter_<<type>>_state
	    SET increasing  = 1    -- order: increasing
	    ,   cursor_code = 1    -- at virtual start
	    ,   cursor_key  = NULL -- ignored due to code
	    ,   cursor_uuid = NULL -- ditto
	    WHERE who = "<<iter>>"
	}

	my Def sql_load_state {
	    SELECT increasing  AS myincreasing
	    ,      cursor_code AS mycode
	    ,      cursor_key  AS mykey
	    ,      cursor_uuid AS myuuid
	    FROM blobiter_<<type>>_state
	    WHERE who = "<<iter>>"
	}

	my Def sql_save_state {
	    UPDATE blobiter_<<type>>_state
	    SET increasing  = :myincreasing
	    ,   cursor_code = :mycode
	    ,   cursor_key  = :mykey
	    ,   cursor_uuid = :myuuid
	    WHERE who = "<<iter>>"
	}

	my Def sql_data {
	    SELECT B.uuid AS uuid
	    ,      I.key  AS key
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	}

	#my Def sql_add_bulk {}

	my Def sql_exists {
	    SELECT count(*)
	    FROM <<iter>>
	    WHERE id = (SELECT id
			FROM <<table>>
			WHERE uuid = :uuid)
	}

	my Def sql_has {
	    SELECT count(*)
	    FROM <<iter>>
	    WHERE id = (SELECT id
			FROM <<table>>
			WHERE uuid = :uuid)
	    AND   key = :key
	}

	my Def sql_size {
	    SELECT count(*) FROM <<iter>>
	}

	my Def sql_forward {
	    SELECT B.uuid AS uuid
	    ,      I.key  AS key
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	    AND ((I.key >= :mykey) OR
		 ((I.key = :mykey) AND (B.uuid >= :myuuid)))
	    ORDER BY I.key ASC, B.uuid ASC
	    LIMIT :n
	}

	my Def sql_backward {
	    SELECT B.uuid AS uuid
	    ,      I.key  AS key
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	    AND ((I.key <= :mykey) OR
		 ((I.key = :mykey) AND (B.uuid <= :myuuid)))
	    ORDER BY I.key DESC, B.uuid DESC
	    LIMIT :n
	}

	my Def sql_min_entry {
	    -- NOTE: Cannot use MIN in a simple form, as the command
            --       returns the MIN of each column independently.
	    --       Could be done as MIN of key, followed by a
            --       separate MIN of uuid within that key. Unclear
            --       which of the forms (current and alternate) would
            --       be faster, and what indices will be required.
	    SELECT I.key  AS key
	    ,      B.uuid AS uuid
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	    ORDER BY key ASC, uuid ASC
	    LIMIT 1
	}

	my Def sql_max_entry {
	    -- NOTE: See sql_min_entry above for note.
	    SELECT I.key  AS key
	    ,      B.uuid AS uuid
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	    ORDER BY key DESC, uuid DESC
	    LIMIT 1
	}

	# Similar to sql_forward. Differences:
	# - Returns both key and uuid.
	# - Looks for 'greater than' current position to get the entry
	# - after the skipped range.
	my Def sql_next {
	    SELECT B.uuid AS myuuid
	    ,      I.key  AS mykey
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	    AND ((I.key > :mykey) OR
		 ((I.key = :mykey) AND (B.uuid > :myuuid)))
	    ORDER BY I.key ASC, B.uuid ASC
	    LIMIT :n
	}

	# Similar to sql_forward. Differences:
	# - Returns both key and uuid.
	# - Looks for 'less than' current position to get the entry
	# - before the skipped range.
	my Def sql_previous {
	    SELECT B.uuid AS myuuid
	    ,      I.key  AS mykey
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	    AND ((I.key < :mykey) OR
		 ((I.key = :mykey) AND (B.uuid < :myuuid)))
	    ORDER BY I.key DESC, B.uuid DESC
	    LIMIT :n
	}

	return
    }

    method Def {var sql} {
	upvar 1 map map
	set $var [string map $map $sql]
	return
    }

    # Debug helper. Show entire iterator table, plus the location of
    # the cursor.
    method /SHOW {} {
	set k 0
	set pre 1
	foreach item [lsort -index 0 [lsort -index 1 [my data]]] {
	    lassign $item key uuid

	    if {($key eq $mykey) && ($uuid eq $myuuid)} {
		set mark *
		set pre 0
	    } else {
		set mark { }
	    }
	    if {$pre &&
		((($key eq $mykey) &&
		  ([string compare $uuid $myuuid] > 0)) ||
		 ([string compare $key $mykey] > 0))} {
		puts [format "* --- %10s %s" $key $uuid]
		set pre 0
	    }
	    puts [format "%s %3d %10s %s" $mark $k $key $uuid]
	    incr k
	}
    }
    #export /SHOW

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob::iter::sqlite 0
return
