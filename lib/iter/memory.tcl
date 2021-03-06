# -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## In-memory blob iteration.

# @@ Meta Begin
# Package blob::iter::memory 1
# Meta author      {Andreas Kupries}
# Meta category    Blob iteration, memory
# Meta description Keep blob iterator in memory
# Meta location    http:/core.tcl.tk/akupries/blob
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     debug
# Meta require     debug::caller
# Meta require     blob::iter
# Meta subject     {blob iterator} iterator memory
# Meta summary     Blob iterator
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require blob::iter
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define blob/iter/memory
debug level  blob/iter/memory
debug prefix blob/iter/memory {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::iter::memory {
    superclass blob::iter

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {{sort -ascii}} {
	debug.blob/iter/memory {}
	set mysort $sort      ;# how to sort the index
	my clear
	next
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    # Add: (uuid property_value) --> ()
    method Add {uuid property_value} {
	debug.blob/iter/memory {}
	# Extend index
	dict set myuuid $uuid $property_value
	lappend mytable [list $uuid $property_value]
	# Signal that we cannot assume proper order anymore.
	set mysorted no
	return
    }

    # remove: (uuid) --> ()
    method Remove {uuid} {
	# The removed element is never at the current cursor location.
	# Our caller (base class) has made sure. And while the actions
	# it took (next 1) ensured that the table is sorted for that
	# case, nothing was done if the element was not the current
	# before.  Thus we cannot assume to be sorted.
	debug.blob/iter/memory {}

	dict unset myuuid $uuid

	# Element is not current. Search for its physical location.
	# IDEA: Use a dict mapping from uuid to location
	#       - Refresh as part of sorting, and part of remove
	set pos [lsearch -glob $mytable [list $uuid *]]

	# Not found -- mytable and myuuid are out of sync!! Should panic
	if {$pos < 0} {
	    debug.blob/iter/memory {not found, ignored}
	    return
	}

	# Found. Remove.
	debug.blob/iter/memory {remove $pos}
	set mytable [lreplace $mytable $pos $pos]
	# TODO: implement K/take

	set current [my CursorLocation]
	# Removal does not de-order the sorted table.
	# However if we removed before the current location, the
	# physical must be corrected.
	if {$pos < $current} {
	    debug.blob/iter/memory {adjust -1}
	    incr myploc -1
	}

	debug.blob/iter/memory {/done}
	return
    }

    method IsCurrent {uuid} {
	if {[lindex $myvloc 0]   ne "at" } { return 0 }
	if {[lindex $myvloc 1 0] eq $uuid} { return 1 }
	return 0
    }

    # clear: () --> ()
    method clear {} {
	debug.blob/iter/memory {}
	set mytable     {}         ;# nothing to iterate over yet
	set myuuid      {}         ;# UUID PK index to guard against duplicate entries
	set mysorted    yes        ;# technically we are sorted
	set mydirection increasing ;# default direction is ascending
	set myvloc      {start {}} ;# logical position at virtual beginning
	set myploc      {}         ;# physical position unknown
	return
    }

    # # ## ### ##### ######## #############

    # reset: () -> ()
    method reset {} {
	debug.blob/iter/memory {}
	my ToBoundary start
	return
    }

    # reverse:  () -> ()
    method reverse {} {
	debug.blob/iter/memory {}
	switch -exact -- $mydirection {
	    increasing { set mydirection decreasing }
	    decreasing { set mydirection increasing }
	}
	if {!$mysorted} return
	# An already sorted table can be reversed easily, without a
	# full resort
	set mytable [lreverse $mytable]
	return
    }

    # next: length --> bool
    method next {n} {
	debug.blob/iter/memory {}
	my ValidatePosInt $n STEP

	set current [my CursorLocation]
	incr current $n

	set pk [lindex $mytable $current]
	if {$pk == {}} {
	    my ToBoundary end
	    debug.blob/iter/memory {@$myploc@$myvloc}
	    return false
	}

	my To $pk $current
	debug.blob/iter/memory {@$myploc@$myvloc}
	return true
    }

    # previous: length --> bool
    method previous {n} {
	debug.blob/iter/memory {}
	my ValidatePosInt $n STEP

	set current [my CursorLocation]
	incr current -$n

	set pk [lindex $mytable $current]
	if {$pk == {}} {
	    my ToBoundary start
	    debug.blob/iter/memory {@$myploc@$myvloc}
	    return false
	}

	my To $pk $current
	debug.blob/iter/memory {@$myploc@$myvloc}
	return true
    }

    # to: pair('start',{})          --> ()
    #     pair('end',{})
    #     pair('at',pair(property_value,uuid))
    method to {location} {
	debug.blob/iter/memory {}

	if {[llength $location] != 2} {
	    my Error "Bad location \"$location\", expected list of 2 elements" \
		INVALID LOCATION SYNTAX
	}

	set type [lindex $location 0]
	switch -exact -- $type {
	    at {
		set pk [my PKvLoc [lindex $location 1]]
		if {![my Has {*}$pk]} {
		    my Error "Bad location \"$location\", not found" \
			INVALID LOCATION UNKNOWN
		}
		my To $pk
	    }
	    start - end {
		my ToBoundary $type
	    }
	    default {
		my Error "Bad location type \"$type\", expected at, end, or start" \
		    INVALID LOCATION TYPE
	    }
	}
	return
    }

    # direction! (string) -> ()
    # __Inherited__ Can't be done better locally

    # data!: (list(tuple(property_value,uuid)) --> ()
    # __Inherited__ Can't be done better locally

    # # ## ### ##### ######## #############

    # Get: (uuid) --> property_value
    method Get {uuid} {
	debug.blob/iter/memory {}
	return [dict get $myuuid $uuid]
    }

    # exists: (uuid) -> bool
    method exists {uuid} {
	debug.blob/iter/memory {==> [dict exists $myuuid $uuid]}
	return [dict exists $myuuid $uuid]
    }

    # size: () --> int
    method size {} {
	debug.blob/iter/memory {==> ([llength $mytable])}
	return [llength $mytable]
    }

    # at: length --> list(uuid)
    method at {n} {
	debug.blob/iter/memory {}
	my ValidatePosInt $n SIZE

	set slice [my Take $n]
	debug.blob/iter/memory {==> ($slice)}
	return $slice
    }

    # direction: () -> string
    method direction {} {
	debug.blob/iter/memory {==> $mydirection}
	return $mydirection
    }

    # location: () -> pair('start',{})
    #              -> pair('end',{})
    #              -> pair('at',pair(property_value,uuid))
    method location {} {
	debug.blob/iter/memory {@l:($myvloc) -- @p:($myploc)}

	set loc $myvloc
	if {[lindex $myvloc 0] eq "at"} {
	    set loc [list at [my PKvLoc [lindex $myvloc 1]]]
	}

	debug.blob/iter/memory {==> ($loc)}
	return $loc
    }

    # data: () -> list(tuple(uuid,property_value))
    method data {} {
	debug.blob/iter/memory {}
	return $mytable
    }

    # # ## ### ##### ######## #############
    ## State

    # Configuration:
    # - mysort    :: option (lsort)       :: How to sort the index, ordering
    # Data:
    # - mytable   :: list(pair(uuid,property_value)) :: Index to iterate over
    # - myuuid    :: dict (uuid -> property_value)   :: Fast existence checks
    # - mysorted  :: bool                            :: Sorting status of mytable,
    #                                                   true <=> sorted.
    # Iterator state:
    # - mydirection :: {"increasing","decreasing"}    :: Direction of iteration
    # - myploc      :: integer                        :: Physical cursor position,
    #                                                    index into mytable
    # - myvloc      :: pair(note,pair(uuid,prop_val)) :: Logical cursor position
    #
    # The logical position can be:
    # - {start {}}      - virtual start
    # - {end {}}        - virtual end (after the table)
    # - {el {uuid property_value}} - exact location (as a pk matching table structure)
    #
    # The physical position can be
    # - an empty string, or
    # - an integer, the index into mytable.
    #
    # Note:
    #	Iteration is always __forward__.
    #	Reversal of direction is accomplished here by physically
    #	reversing the index table when needed.

    variable mysort mytable myuuid mysorted mydirection myploc myvloc

    # # ## ### ##### ######## #############
    # Internal helper methods

    method PKvLoc {pair} {
	lassign $pair a b
	list $b $a
    }

    method Take {n} {
	debug.blob/iter/memory {}
	set start [my CursorLocation]
	set end   [expr {$start + $n - 1}]
	set slice [lrange $mytable $start $end]
	debug.blob/iter/memory {==> [llength $slice]:($slice)}
	return $slice
    }

    method CursorLocation {} {
	debug.blob/iter/memory {}
	my EnsureSorted
	if {$myploc == {}} {
	    # Physical position not known/invalid.
	    # Compute from logical position, then return
	    switch -glob -- $myvloc {
		{start *} { set myploc 0 }
		{end *}   { set myploc [llength $mytable] }
		{at *}    {
		    set myploc [lsearch -exact $mytable [lindex $myvloc 1]]
		}
	    }
	} ;# Position is known/cached, simply return
	return $myploc
    }

    method EnsureSorted {} {
	debug.blob/iter/memory {}
	if {$mysorted} return
	# Table was extended without regard to order. Resort now.  We
	# are taking direction into account here to get the table in
	# the proper order. Sorting is done inside out, uuid first,
	# then property_value, given a final order of by
	# property_value, then by uuid.

	set mytable [lsort -$mydirection $mysort -index 1 \
			 [lsort -$mydirection -ascii -index 0 \
			      $mytable]]

	# Invalidate the physical position
	set myploc {}
	return
    }

    method ToBoundary {s} {
	debug.blob/iter/memory {}
	set myvloc [list $s {}] ;# logical position at virtual boundary
	set myploc {}	        ;# physical position unknown
	return
    }

    method To {pk {phys {}}} {
	debug.blob/iter/memory {}
	set myvloc [list at $pk] ;# logical position via primary property_value
	set myploc $phys         ;# physical position unknown by
				  # default, caller may know and set
	return
    }

    method Has {uuid property_value} {
	debug.blob/iter/memory {}
	if {![dict exists $myuuid $uuid]} { return 0 }
	return [expr {[dict get $myuuid $uuid] eq $property_value}]
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob::iter::memory 0
return
