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

# # ## ### ##### ######## ############# #####################
## Notes

# (1) By default all property-values are sorted in natural order for
#     their type (INT, TEXT). To impose a custom order on TEXT data
#     (define and) use a collation sequence.
#
#     The default sequences known to all databases are
#     BINARY - (default) - memcmp(), ignore encodings
#     NOCASE - Fold the ASCII uppercase to lowercase for comparison
#              !! No full UTF folding.
#     RTRIM  - See BINARY, plus ignore trailing ASCII space characters.
#
#     Anything beyond that has to be implement as either a
#     C-extension, or as a Tcl procedure attached to the database with
#     [DB collate $procname]
#
#     Relevant rules:
#       https://www.sqlite.org/datatype3.html#collation
#
#     With a sidecar the user has control over the value table, and
#     thus can add the collation.
#
#     Without a sidecar, use option -collation to tell the iterator
#     what to use.
#

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require blob::iter
package require blob::table
package require blob::option
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

    constructor {db args} {
	debug.blob/iter/sqlite {}

	# See if there is a way to make this a deeper part of the
	# class definition, with auto-placement into the instance.
	blob::option create [self namespace]::OPTION {
	    {-blob-table   blob}
	    {-iter-table   blobiter}
	    {-type         TEXT}
	    {-value-table  {}}
	    {-value-column val}
	    {-collation    {}}
	}
	# Notes:
	# -value-table  - Default => Store values in iter table.
	# -value-column - Name of column for values in the value-table  
	#                 Ignored when operating without value-table	   
	# -collation    - Custom ordering, with and without value-table.
	OPTION configure-list $args

	# Make the database available as a local command, under a
	# fixed name. No need for an instance variable and resolution.
	interp alias {} [self namespace]::DB {} $db

	# Configure the sql commands with the tables to use, the type
	# of the property_value column, and the sidecar for the
	# values, if any (empty when no sidecar is to be used)
	my InitializeSchema
	my LoadState
	next
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    # Add: (uuid property_value) --> ()
    method Add {uuid pval} {
	debug.blob/iter/sqlite {}

	# TODO, MAYBE: Separate validation of value,
	# TODO, MAYBE: to enable the generation of a
	# TODO, MAYBE: nicer error message
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

	# (n > 0) ==> (count > 0) <=> (count is defined)

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

    # Get: (uuid) --> property_value
    method Get {uuid} {
	debug.blob/iter/sqlite {}
	DB transaction {
	    set value [DB onecolumn $sql_get]
	}
	debug.blob/iter/sqlite {==> $value}
	return $value
    }

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
	sql_get         \
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
		my Error "Internal use of bad boundary value \"$s\"" \
		    INTERNAL BAD BOUNDARY
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
	lassign $pos myuuid mypval
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

    method InitializeSchema {} {
	debug.blob/iter/sqlite {}

	set table      [OPTION cget -blob-table]
	set itertable  [OPTION cget -iter-table]
	set type       [OPTION cget -type]
	set sidetable  [OPTION cget -value-table]
	set sidecolumn [OPTION cget -value-column]
	set collation  [OPTION cget -collation]

	lappend map @iter@  $itertable
	lappend map @otype@ $type

	if {$sidetable eq ""} {
	    # No sidecar. Ordering is directly on the iteration table.
	    # Value and ordering type are the same.
	    set vtype $type

	    lappend map @property-value@ "I.pval"
	    lappend map @side-table@     ""
	    lappend map @side-link@      ""
	    lappend map @new-p-value@    ":pval"

	} else {
	    if {$sidecolumn eq ""} {
		my Error \
		    "Bad name for value column in side table, must not be empty" \
		    INVALID SIDECAR SPEC
	    }

	    # Sidecar present. With the actual property values held in
	    # the sidecar S the itertable's value column becomes a
	    # foreign key reference into S, i.e. a plain integer. The
	    # ordering is of the specified type in the sidecar.
	    set vtype INTEGER

	    lappend map @property-value@ "V.$sidecolumn"
	    lappend map @side-table@     ", $sidetable V"
	    lappend map @side-link@      "AND I.pval = V.id"
	    lappend map @new-p-value@    \
		"(SELECT id FROM $sidetable WHERE $sidecolumn = :pval)"

	    # Note: There is no functional need for a separate
	    # validation of incoming property values. If the value is
	    # missing in the sidecar the SELECT above will return
	    # NULL, which will then trigger the NOT NULL constraint on
	    # the pval column in the iterator table when we try to
	    # insert.
	    #
	    # -- However we might wish to do a separate validation
	    #    even so, to generate a nicer/clearer error message.
	}

	if {$table ne {}} {
	    # Attached to a blob table, which stores the actual uuids.
	    set finduuid "(SELECT id FROM $table WHERE uuid = :uuid)"
	    lappend map @new-uuid@   "$finduuid"
	    lappend map @match-uuid@ "id = $finduuid"
	    lappend map @uuid@       "B.uuid"
	    lappend map @blob-table@ ", $table B"
	    lappend map @blob-link@  "I.id = B.id"
	} else {
	    # Autark. No connected blob table. The uuid is stored in
	    # the iterator itself.
	    lappend map @new-uuid@   "NULL, :uuid"
	    lappend map @match-uuid@ "uuid = :uuid"
	    lappend map @uuid@       "I.uuid"
	    lappend map @blob-table@ ""
	    lappend map @blob-link@  "1=1"
	}

	set fqndb [self namespace]::DB

	blob::table::iter  $fqndb $table $itertable $vtype $type $collation

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
	# Note: The iterator uses by default the @table@.uuid to
	#       find relevant UUIDs, and thus avoids the need for
	#       saving its own duplicates. This is called
	#       "attached to @table@".
	#
	#       This can be disabled by setting -blob-table to "".
	#       In that case the uuids are stored directly into the
	#       iterator table. This is called "autark"
	#
	#       As a side point, it is possible to use an autark
	#       iterator as the blob table another iterator can attach
	#       to. This is possible because autark iterators use a
	#       column "uuid" for the uuids, like a regular sqlite
	#       blob store.

	my Def sql_add {
	    INSERT INTO @iter@ VALUES (@new-uuid@, @new-p-value@)
	}

	my Def sql_remove {
	    DELETE FROM @iter@ WHERE @match-uuid@
	}

	my Def sql_clear {
	    DELETE FROM @iter@
	}

	my Def sql_reset_state {
	    UPDATE blobiter_@otype@_state
	    SET increasing  = 1    -- order: increasing
	    ,   cursor_code = 1    -- at virtual start
	    ,   cursor_pval = NULL -- ignored due to code
	    ,   cursor_uuid = NULL -- ditto
	    WHERE who = "@iter@"
	}

	my Def sql_load_state {
	    SELECT increasing  AS myincreasing
	    ,      cursor_code AS mycode
	    ,      cursor_pval AS mypval
	    ,      cursor_uuid AS myuuid
	    FROM blobiter_@otype@_state
	    WHERE who = "@iter@"
	}

	my Def sql_save_state {
	    UPDATE blobiter_@otype@_state
	    SET increasing  = :myincreasing
	    ,   cursor_code = :mycode
	    ,   cursor_pval = :mypval
	    ,   cursor_uuid = :myuuid
	    WHERE who = "@iter@"
	}

	my Def sql_data {
	    SELECT @uuid@           AS uuid
	    ,      @property-value@ AS pval
	    FROM @iter@ I  @blob-table@  @side-table@
	    WHERE	   @blob-link@   @side-link@
	}

	#my Def sql_add_bulk {}

	my Def sql_exists {
	    SELECT count(*) FROM @iter@ WHERE @match-uuid@
	}

	my Def sql_get {
	    SELECT @property-value@
	    FROM @iter@ I        @side-table@
	    WHERE I.@match-uuid@ @side-link@
	}

	my Def sql_has {
	    SELECT count(*)
	    FROM @iter@ I        @side-table@
	    WHERE I.@match-uuid@ @side-link@
	    AND   @property-value@ = :pval
	}

	my Def sql_size {
	    SELECT count(*) FROM @iter@
	}

	my Def sql_forward {
	    SELECT @uuid@           AS uuid
	    ,      @property-value@ AS pval
	    FROM @iter@ I  @blob-table@  @side-table@
	    WHERE	   @blob-link@ @side-link@
	    AND ((@property-value@  >= :mypval) OR
		 ((@property-value@  = :mypval) AND (@uuid@ >= :myuuid)))
	    ORDER BY @property-value@ ASC
	    ,        @uuid@           ASC
	    LIMIT :n
	}

	my Def sql_backward {
	    SELECT @uuid@           AS uuid
	    ,      @property-value@ AS pval
	    FROM @iter@ I  @blob-table@ @side-table@
	    WHERE	   @blob-link@  @side-link@
	    AND ((@property-value@  <= :mypval) OR
		 ((@property-value@  = :mypval) AND (@uuid@ <= :myuuid)))
	    ORDER BY @property-value@ DESC
	    ,        @uuid@           DESC
	    LIMIT :n
	}

	# NOTE: Cannot use MIN in a simple form, as the command
	#       returns the MIN of each column independently.
	#       Could be done as MIN of pval, followed by a
	#       separate MIN of uuid within that pval. Unclear
	#       which of the forms (current and alternate) would
	#       be faster, and what indices will be required.
	my Def sql_min_entry {
	    SELECT @uuid@           AS uuid
	    ,      @property-value@ AS pval
	    FROM @iter@ I  @blob-table@ @side-table@
	    WHERE	   @blob-link@  @side-link@
	    ORDER BY @property-value@ ASC
	    ,        @uuid@           ASC
	    LIMIT 1
	}

	# NOTE: See sql_min_entry above for note.
	my Def sql_max_entry {
	    SELECT @uuid@           AS uuid
	    ,      @property-value@ AS pval
	    FROM @iter@ I  @blob-table@ @side-table@
	    WHERE	   @blob-link@  @side-link@
	    ORDER BY @property-value@ DESC
	    ,        @uuid@           DESC
	    LIMIT 1
	}

	# Similar to sql_forward. Differences:
	# - Returns to directly to object state (my{uuid,pval})
	# - Looks for 'greater than' current position to get the entry
	# - __after__ the skipped range.

	my Def sql_next {
	    SELECT @uuid@           AS myuuid
	    ,      @property-value@ AS mypval
	    FROM @iter@ I  @blob-table@ @side-table@
	    WHERE	   @blob-link@  @side-link@
	    AND ((@property-value@   > :mypval) OR
		 ((@property-value@  = :mypval) AND (@uuid@ > :myuuid)))
	    ORDER BY @property-value@ ASC
	    ,        @uuid@           ASC
	    LIMIT :n
	}

	# Similar to sql_forward. Differences:
	# - Returns to directly to object state (my{uuid,pval})
	# - Looks for 'less than' current position to get the entry
	# - __before__ the skipped range.

	my Def sql_previous {
	    SELECT @uuid@           AS myuuid
	    ,      @property-value@ AS mypval
	    FROM @iter@ I  @blob-table@ @side-table@
	    WHERE	   @blob-link@  @side-link@
	    AND ((@property-value@   < :mypval) OR
		 ((@property-value@  = :mypval) AND (@uuid@ < :myuuid)))
	    ORDER BY @property-value@ DESC
	    ,        @uuid@           DESC
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
