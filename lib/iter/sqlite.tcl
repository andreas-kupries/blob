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
# Meta require     blob::table
# Meta subject     {blob iterator} iterator sqlite
# Meta summary     Blob iterator
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Limitation

# Currently only able to order on the stored propery-value.
# This is a problem where that value is just row-id, i.e. foreign key
# reference into a separate table holding the actual values.
# This situation will occur when the property values are interned, see
# package Atom.

# TODO: Resolve the limitation on sorting.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require blob::iter
package require blob::table
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
	# type of the property_value column.
	my InitializeSchema $table $itertable $type
	my LoadState
	next
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    # Add: (uuid property_value) --> ()
    method Add {uuid pval} {
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

	debug.blob/iter/sqlite {/done}
	return
    }

    method IsCurrent {uuid} {
	debug.blob/iter/sqlite {}
	return [expr {($mycode == 2) && ($myuuid eq $uuid)}]
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
	set mypval       {}
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
    #     pair('at',pair(property_value,uuid))
    method to {location} {
	debug.blob/iter/sqlite {}

	if {[llength $location] != 2} {
	    my Error "Bad location \"$location\", expected list of 2 elements" \
		INVALID LOCATION SYNTAX
	}

	set type [lindex $location 0]
	switch -exact -- $type {
	    at {
		lassign [lindex $location 1] pval uuid
		set has [DB eval $sql_has]
		if {!$has} {
		    my Error "Bad location \"$location\", not found" \
			INVALID LOCATION UNKNOWN
		}
		my To $pval $uuid no
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

    # data!: (list(tuple(property_value,uuid)) --> ()
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

    # at: length --> list(tuple(property_value,uuid))
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
		    lappend slice [list $uuid $pval]
		}
	    }
	} else {
	    DB transaction {
		DB eval $sql_backward {
		    lappend slice [list $uuid $pval]
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

    # location: () -> tuple(property_value,uuid)
    method location {} {
	debug.blob/iter/sqlite {@l:($mycode ($mypval $myuuid))}

	switch -exact -- $mycode {
	    1 { set loc {start {}} }
	    3 { set loc {end {}} }
	    2 { set loc [list at [list $mypval $myuuid]] }
	}

	debug.blob/iter/sqlite {==> ($loc)}
	return $loc
    }

    # data: () -> list(tuple(uuid,property_value))
    method data {} {
	debug.blob/iter/sqlite {}
	set r {}
	DB transaction {
	    DB eval $sql_data {
		lappend r [list $uuid $pval]
	    }
	}
	return $r
    }

    # # ## ### ##### ######## #############
    ## State

    # myincreasing - {0,1} - Sort order
    # mycode       - {1,2,3} - Cursor state
    #                1 = start = cursor at virtual start, ignore pval/uuid
    #                2 = el    = cursor at specific pval/uuid
    #                3 = end   = cursor at virtual end, ignore pval/uuid
    # mypval       - Primary cursor position:   property-value
    # myuuid       - Secondary cursor position: blob uuid

    # Configuration:
    variable \
	myincreasing mycode mypval myuuid \
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

    method To {pval uuid {save yes}} {
	debug.blob/iter/sqlite {}
	set mycode 2
	set mypval $pval
	set myuuid $uuid
	if {$save} { my SaveState }
	return
    }

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
	lassign $pos mypval myuuid
	my SaveState
	return true
    }

    method LoadState {} {
	debug.blob/iter/sqlite {}
	set myincreasing 1
	set mycode       1
	set mypval       {}
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

	blob::table::store $fqndb $table
	blob::table::iter  $fqndb $itertable $type

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
	# . test uuid+pval for existence
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
		    :pval)
	}

	my Def sql_remove {
	    DELETE
	    FROM <<iter>>
	    WHERE id = (SELECT id
			FROM <<table>>
			WHERE uuid = :uuid)
	}

	my Def sql_clear {
	    DELETE FROM <<iter>>
	}

	my Def sql_reset_state {
	    UPDATE blobiter_<<type>>_state
	    SET increasing  = 1    -- order: increasing
	    ,   cursor_code = 1    -- at virtual start
	    ,   cursor_pval = NULL -- ignored due to code
	    ,   cursor_uuid = NULL -- ditto
	    WHERE who = "<<iter>>"
	}

	my Def sql_load_state {
	    SELECT increasing  AS myincreasing
	    ,      cursor_code AS mycode
	    ,      cursor_pval AS mypval
	    ,      cursor_uuid AS myuuid
	    FROM blobiter_<<type>>_state
	    WHERE who = "<<iter>>"
	}

	my Def sql_save_state {
	    UPDATE blobiter_<<type>>_state
	    SET increasing  = :myincreasing
	    ,   cursor_code = :mycode
	    ,   cursor_pval = :mypval
	    ,   cursor_uuid = :myuuid
	    WHERE who = "<<iter>>"
	}

	my Def sql_data {
	    SELECT B.uuid AS uuid
	    ,      I.pval AS pval
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
	    AND   pval = :pval
	}

	my Def sql_size {
	    SELECT count(*) FROM <<iter>>
	}

	my Def sql_forward {
	    SELECT B.uuid AS uuid
	    ,      I.pval AS pval
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	    AND ((I.pval >= :mypval) OR
		 ((I.pval = :mypval) AND (B.uuid >= :myuuid)))
	    ORDER BY I.pval ASC, B.uuid ASC
	    LIMIT :n
	}

	my Def sql_backward {
	    SELECT B.uuid AS uuid
	    ,      I.pval  AS pval
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	    AND ((I.pval <= :mypval) OR
		 ((I.pval = :mypval) AND (B.uuid <= :myuuid)))
	    ORDER BY I.pval DESC, B.uuid DESC
	    LIMIT :n
	}

	my Def sql_min_entry {
	    -- NOTE: Cannot use MIN in a simple form, as the command
            --       returns the MIN of each column independently.
	    --       Could be done as MIN of pval, followed by a
            --       separate MIN of uuid within that pval. Unclear
            --       which of the forms (current and alternate) would
            --       be faster, and what indices will be required.
	    SELECT I.pval AS pval
	    ,      B.uuid AS uuid
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	    ORDER BY pval ASC, uuid ASC
	    LIMIT 1
	}

	my Def sql_max_entry {
	    -- NOTE: See sql_min_entry above for note.
	    SELECT I.pval AS pval
	    ,      B.uuid AS uuid
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	    ORDER BY pval DESC, uuid DESC
	    LIMIT 1
	}

	# Similar to sql_forward. Differences:
	# - Returns both pval and uuid.
	# - Looks for 'greater than' current position to get the entry
	# - __after__ the skipped range.
	my Def sql_next {
	    SELECT B.uuid AS myuuid
	    ,      I.pval AS mypval
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	    AND ((I.pval > :mypval) OR
		 ((I.pval = :mypval) AND (B.uuid > :myuuid)))
	    ORDER BY I.pval ASC, B.uuid ASC
	    LIMIT :n
	}

	# Similar to sql_forward. Differences:
	# - Returns both pval and uuid.
	# - Looks for 'less than' current position to get the entry
	# - __before__ the skipped range.
	my Def sql_previous {
	    SELECT B.uuid AS myuuid
	    ,      I.pval AS mypval
	    FROM <<table>> B
	    ,    <<iter>>  I
	    WHERE I.id = B.id
	    AND ((I.pval < :mypval) OR
		 ((I.pval = :mypval) AND (B.uuid < :myuuid)))
	    ORDER BY I.pval DESC, B.uuid DESC
	    LIMIT :n
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
package provide blob::iter::sqlite 0
return
