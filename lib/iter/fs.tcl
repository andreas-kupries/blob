# -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## Filesystem-based blob iteration.

# @@ Meta Begin
# Package blob::iter::fs 1
# Meta author      {Andreas Kupries}
# Meta category    Blob iteration, fs
# Meta description Keep blob iterator in fs
# Meta location    http:/core.tcl.tk/akupries/blob
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     debug
# Meta require     debug::caller
# Meta require     blob::iter
# Meta subject     {blob iterator} iterator fs
# Meta summary     Blob iterator
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Notes

# This iterator is strongly related to the in-memory
# implementation. This is because during operation the instance keeps
# all its information in memory, loading the persistent state during
# construction and saving only changes. It especially does not even
# try to keep the persistent state ordered, this is all only in
# memory. The only "optimization" done is the keeping of uuids for
# distinct property values in separate files.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require blob::iter
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define blob/iter/fs
debug level  blob/iter/fs
debug prefix blob/iter/fs {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::iter::fs {
    superclass blob::fsbase blob::iter

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {statedir {sort -ascii}} {
	debug.blob/iter/fs {}
	lappend mymap   \n %n \r %r \t %t { } %s / %/ \\ %\\ : %c % %%
	lappend myremap %n \n %r \r %t \t %s { } %/ / %\\ \\ %c : %% %

	set mysort $sort      ;# how to sort the index
	my clear
	next $statedir
	my LoadData
	my LoadCursor
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    # Add: (uuid property_value) --> ()
    method Add {uuid property_value} {
	debug.blob/iter/fs {}
	# Extend index
	dict set     myuuid $uuid $property_value
	dict lappend mykey  $property_value $uuid
	lappend mytable [list $uuid $property_value]
	# Signal that we cannot assume proper order anymore.
	set mysorted no
	my SaveData $property_value
	return
    }

    # remove: (uuid) --> ()
    method Remove {uuid} {
	# The removed element is never at the current cursor location.
	# Our caller (base class) has made sure. And while the actions
	# it took (next 1) ensured that the table is sorted for that
	# case, nothing was done if the element was not the current
	# before.  Thus we cannot assume to be sorted.
	debug.blob/iter/fs {}

	dict unset myuuid $uuid

	# Element is not current. Search for its physical location.
	# IDEA: Use a dict mapping from uuid to location
	#       - Refresh as part of sorting, and part of remove
	set pos [lsearch -glob $mytable [list $uuid *]]

	# Not found -- mytable and myuuid are out of sync!! Should panic
	if {$pos < 0} {
	    debug.blob/iter/fs {not found, ignored}
	    return
	}

	# Found. Remove.
	debug.blob/iter/fs {remove $pos}
	set key     [lindex   $mytable $pos 1]
	set mytable [lreplace $mytable $pos $pos]
	# TODO: implement K/take

	# And remove from per-key shard
	set shard [dict get $mykey $key]
	set pos [lsearch -exact $shard $uuid]
	dict set mykey $key [lreplace $shard $pos $pos]

	set current [my CursorLocation]
	# Removal does not de-order the sorted table.
	# However if we removed before the current location, the
	# physical must be corrected.
	if {$pos < $current} {
	    debug.blob/iter/fs {adjust -1}
	    incr myploc -1
	}

	my SaveData $key
	debug.blob/iter/fs {/done}
	return
    }

    method IsCurrent {uuid} {
	if {[lindex $myvloc 0]   ne "at" } { return 0 }
	if {[lindex $myvloc 1 0] eq $uuid} { return 1 }
	return 0
    }

    # clear: () --> ()
    method clear {} {
	debug.blob/iter/fs {}
	set mytable     {}         ;# nothing to iterate over yet
	set myuuid      {}         ;# UUID PK index to guard against duplicate entries
	set mykey       {}         ;# key -> list(uuid) for faster manipulation of the
	                            #                   persistent state
	set mysorted    yes        ;# technically we are sorted
	set mydirection increasing ;# default direction is ascending
	set myvloc      {start {}} ;# logical position at virtual beginning
	set myploc      {}         ;# physical position unknown
	return
    }

    # # ## ### ##### ######## #############

    # reset: () -> ()
    method reset {} {
	debug.blob/iter/fs {}
	my ToBoundary start
	return
    }

    # reverse:  () -> ()
    method reverse {} {
	debug.blob/iter/fs {}
	switch -exact -- $mydirection {
	    increasing { set mydirection decreasing }
	    decreasing { set mydirection increasing }
	}
	my SaveCursor
	if {!$mysorted} return
	# An already sorted table can be reversed easily, without a
	# full resort
	set mytable [lreverse $mytable]
	return
    }

    # next: length --> bool
    method next {n} {
	debug.blob/iter/fs {}
	my ValidatePosInt $n STEP

	set current [my CursorLocation]
	incr current $n

	set pk [lindex $mytable $current]
	if {$pk == {}} {
	    my ToBoundary end
	    debug.blob/iter/fs {@$myploc@$myvloc}
	    return false
	}

	my To $pk $current
	my SaveCursor
	debug.blob/iter/fs {@$myploc@$myvloc}
	return true
    }

    # previous: length --> bool
    method previous {n} {
	debug.blob/iter/fs {}
	my ValidatePosInt $n STEP

	set current [my CursorLocation]
	incr current -$n

	set pk [lindex $mytable $current]
	if {$pk == {}} {
	    my ToBoundary start
	    debug.blob/iter/fs {@$myploc@$myvloc}
	    return false
	}

	my To $pk $current
	my SaveCursor
	debug.blob/iter/fs {@$myploc@$myvloc}
	return true
    }

    # to: pair('start',{})          --> ()
    #     pair('end',{})
    #     pair('at',pair(property_value,uuid))
    method to {location} {
	debug.blob/iter/fs {}

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
		my ToBoundary $type no
	    }
	    default {
		my Error "Bad location type \"$type\", expected at, end, or start" \
		    INVALID LOCATION TYPE
	    }
	}
	my SaveCursor
	return
    }

    # direction! (string) -> ()
    # __Inherited__ Can't be done better locally

    # data!: (list(tuple(property_value,uuid)) --> ()
    # __Inherited__ Can't be done better locally

    # # ## ### ##### ######## #############

    # Get: (uuid) --> property_value
    method Get {uuid} {
	debug.blob/iter/fs {}
	return [dict get $myuuid $uuid]
    }

    # exists: (uuid) -> bool
    method exists {uuid} {
	debug.blob/iter/fs {==> [dict exists $myuuid $uuid]}
	return [dict exists $myuuid $uuid]
    }

    # size: () --> int
    method size {} {
	debug.blob/iter/fs {==> ([llength $mytable])}
	return [llength $mytable]
    }

    # at: length --> list(uuid)
    method at {n} {
	debug.blob/iter/fs {}
	my ValidatePosInt $n SIZE

	set slice [my Take $n]
	debug.blob/iter/fs {==> ($slice)}
	return $slice
    }

    # direction: () -> string
    method direction {} {
	debug.blob/iter/fs {==> $mydirection}
	return $mydirection
    }

    # location: () -> pair('start',{})
    #              -> pair('end',{})
    #              -> pair('at',pair(property_value,uuid))
    method location {} {
	debug.blob/iter/fs {@l:($myvloc) -- @p:($myploc)}

	set loc $myvloc
	if {[lindex $myvloc 0] eq "at"} {
	    set loc [list at [my PKvLoc [lindex $myvloc 1]]]
	}

	debug.blob/iter/fs {==> ($loc)}
	return $loc
    }

    # data: () -> list(tuple(uuid,property_value))
    method data {} {
	debug.blob/iter/fs {}
	return $mytable
    }

    # # ## ### ##### ######## #############
    ## State

    # Configuration:
    # - mysort    :: option (lsort)       :: How to sort the index, ordering
    # Data:
    # - mytable   :: list(pair(uuid,property_value)) :: Index to iterate over
    # - myuuid    :: dict (uuid -> property_value)   :: Fast existence checks
    # - mykey     :: dict (p-value -> list(uuid))    :: Fast removal in external state
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

    variable mysort mytable myuuid mykey \
	mysorted mydirection myploc myvloc \
	mymap myremap

    # # ## ### ##### ######## #############
    # Internal helper methods

    method PKvLoc {pair} {
	lassign $pair a b
	list $b $a
    }

    method Take {n} {
	debug.blob/iter/fs {}
	set start [my CursorLocation]
	set end   [expr {$start + $n - 1}]
	set slice [lrange $mytable $start $end]
	debug.blob/iter/fs {==> [llength $slice]:($slice)}
	return $slice
    }

    method CursorLocation {} {
	debug.blob/iter/fs {}
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
	debug.blob/iter/fs {}
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

    method ToBoundary {s {save yes}} {
	debug.blob/iter/fs {}
	set myvloc [list $s {}] ;# logical position at virtual boundary
	set myploc {}	        ;# physical position unknown
	if {$save} { my SaveCursor }
	return
    }

    method To {pk {phys {}}} {
	debug.blob/iter/fs {}
	set myvloc [list at $pk] ;# logical position via primary property_value
	set myploc $phys         ;# physical position unknown by
				  # default, caller may know and set
	return
    }

    method Has {uuid property_value} {
	debug.blob/iter/fs {}
	if {![dict exists $myuuid $uuid]} { return 0 }
	return [expr {[dict get $myuuid $uuid] eq $property_value}]
    }

    method LoadData {} {
	debug.blob/iter/fs {}
	foreach spath [glob -nocomplain -directory [my base] k.*] {
	    set value [string map $myremap [string range [file tail $path] 2 end]]
	    set chan  [open $spath r]
	    set uuids [split [read $chan] \n]
	    close $chan
	    foreach uuid $uuids { my Add $uuid $value }
	}
	return
    }

    method LoadCursor {} {
	debug.blob/iter/fs {}
	set cpath [file join [my base] at]
	if {![file exists $cpath]} return
	set chan [open $cpath r]
	lassign [split [read $chan] \n] type uuid value direction
	close $chan
	if {$type eq "at"} {
	    set loc [list $type [list $uuid $value]]
	} else {
	    set loc [list $type {}]
	}
	my direction! $direction
	my to $loc
	return
    }

    method SaveData {key} {
	debug.blob/iter/fs {}
	set kpath [file join [my base] k.[string map $mymap $key]]
	set chan [open ${kpath}.new w]
	puts -nonewline $chan [join [dict get $mykey $key] \n]
	close $chan
	file rename -force ${kpath}.new $kpath
	return
    }

    method SaveCursor {} {
	debug.blob/iter/fs {}
	set cpath [file join [my base] at]
	lassign $myvloc  type details
	lassign $details uuid value
	set chan [open ${cpath}.new w]
	puts -nonewline $chan [join [list $type $uuid $value [my direction]] \n]
	close $chan
	file rename -force ${cpath}.new $cpath
	return
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob::iter::fs 0
return
