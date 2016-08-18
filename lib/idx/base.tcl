# -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## Base class for iterators over associative blob storage.
##
## This class declares the API all actual iterator classes have to
## implement. It also provides standard APIs for the de(serialization)
## of iterators.

# @@ Meta Begin
# Package blob::iter 1
# Meta author      {Andreas Kupries}
# Meta category    Blob storage iterator, database
# Meta description Base class for iterators over blob stores
# Meta location    http:/core.tcl.tk/akupries/blob
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     debug
# Meta require     debug::caller
# Meta subject     {blob iterator} iterator
# Meta summary     Blob iterator
# @@ Meta End

# # ## ### ##### ######## ############# #####################
##
# Notes:
# - The internals indices of iterators maps arbitrary keys to blob
#   uuids.
#
# - A cursor position is fully specified by the 'key' we are at, and
#   the 'uuid' under that key.
#
#   Note that while uuids are unique, the keys are not. We can have
#   multiple entries with the same key, and different uuids. That is
#   why the cursor position requires the uuid as well, to disambiguate
#   between entries with the same key.
#
# - The semantics of [at], [next], and [previous] with regard to the
#   cursor position are this:
#
#   - The result of [at] includes the data for the cursor position
#     itself, if it exists in the iterator.
#
#   - The operation [next] includes the cursor position in the count
#     of elements to skip, if it exists in the iterator. After the
#     operation the new cursor position is either on the first element
#     after the skipped elements, or the virtual end (on overshot)
#
#   - The operation [previous] __excludes__ the cursor position from
#     the count of elements to skip, if it exists in the
#     iterator. After the operation the new cursor position is either
#     on the first element of the new range, or the virtual start (on
#     overshot).

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define blob/iter
debug level  blob/iter
debug prefix blob/iter {[debug caller] | }
#debug prefix blob/iter {} ;# No prefix, arguments can be large

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::iter {
    # # ## ### ##### ######## #############
    ## Lifecycle

    constructor {} {
	debug.blob/iter {}
	return
    }

    # # ## ### ##### ######## #############
    ## API. Content manipulation

    # add: (uuid key) --> ()
    # Extend iterator with new element
    method add {uuid key} {
	debug.blob/iter {}
	if {[my exists $uuid]} {
	    my Error "Duplicate UUID \"$uuid\"" UUID DUPLICATE
	}
	my Add $uuid $key
	return
    }

    method Add {uuid key} { my API.error Add }

    # remove: (uuid...) --> ()
    # Take element out of the iterator
    method remove {uuid args} {
	debug.blob/iter {}
	foreach uuid [linsert $args 0 $uuid] {
	    if {![my exists $uuid]} {
		debug.blob/iter {not found, ignored}
		continue
	    }
	    my Remove $uuid
	}
	return
    }

    method Remove {uuid} { my API.error Remove }

    # clear: () --> ()
    # Shrink iterator to nothing
    method clear {} { my API.error clear }

    # data!: (list(tuple(uuid,key)) --> ()
    # Load iterator with bulk data (bulk add)
    method data! {tuples} {
	debug.blob/iter {}
	# Validate data first, ...
	foreach pair $tuples {
	    set uuid [lindex $pair 0]
	    if {[my exists $uuid]} {
		my Error "Duplicate UUID \"$uuid\"" UUID DUPLICATE
	    }
	}
	# ... then add if there are no conflicts
	foreach pair $tuples {
	    my Add {*}$pair
	}
	return
    }

    # # ## ### ##### ######## #############
    ## API. Cursor manipulation

    # reset: () -> ()
    # Set cursor to (virtual) start
    method reset {} { my API.error reset }

    # reverse:  () -> ()
    # Change direction of cursor
    method reverse {} { my API.error reverse }

    # Note: The meaning and semantics of next, previous, start, and
    # end are all in terms of the direction of the cursor.

    # next: n --> bool
    # Move the cursor forward by n elements. Return false when
    # reaching beyond the end of the index, and position at the
    # (virtual) end. Further calls will return false too.
    method next {n} { my API.error next }

    # previous: n --> bool
    # Move the cursor backward by n elements. Return false when
    # reaching before the start of the index, and position at the
    # (virtual) start. Further calls will return false too.
    method previous {n} { my API.error previous }

    # to: pair('start',{})          --> ()
    #     pair('end',{})
    #     pair('at',pair(key,uuid))
    # Move the cursor to a specific location.
    method to {location} { my API.error to }

    # direction! (string) -> ()
    # Set cursor direction
    method direction! {dir} {
	debug.blob/iter {}
	my ValidateDirection $dir
	if {$dir eq [my direction]} {
	    debug.blob/iter {No change, nothing to do}
	    return
	}
	# Change from current direction, apply
	my reverse
	return
    }

    # # ## ### ##### ######## #############
    ## API. Introspection

    # exists: (uuid) -> bool
    # Check if uuid is already known
    method exists {uuid} { my API.error exists }

    # size: () --> int
    # Return number of entries in the index
    method size {} { my API.error size }

    # at: length --> list(tuple(uuid,key))
    # Return elements of the index at the cursor position.
    method at {n} { my API.error at }

    # direction: () -> string
    # Query cursor for its direction
    method direction {} { my API.error direction }

    # location: () -> pair('start',{})
    #              -> pair('end',{})
    #              -> pair('at',pair(key,uuid))
    # Query cursor for current position.
    method location {} { my API.error location }

    # data: () -> list(tuple(uuid,key))
    # Query whole iterator
    method data {} { my API.error data }

    # # ## ### ##### ######## #############
    ## API. De(serialization)

    method --> {dst} {
	debug.blob/iter {}
	$dst reset
	$dst clear
	$dst direction! [my direction]
	$dst data!      [my data]
	$dst to         [my location]
	return
    }

    method := {src} {
	debug.blob/iter {}
	my reset
	my clear
	my direction! [$src direction]
	my data!      [$src data]
	my to         [$src location]
	return
    }

    export :=
    export -->

    # # ## ### ##### ######## #############
    ## Internal helpers

    method ValidatePosInt {x code} {
	debug.blob/iter {}
	if {[string is integer -strict $x] && ($x > 0)} return
	my Error "Bad [string tolower $code], expected integer > 0, got $x" \
	    INVALID $code
    }

    method ValidateDirection {x} {
	debug.blob/iter {}
	if {$x in {increasing decreasing}} return
	my Error "Bad direction \"$x\", expected decreasing, or increasing" \
	    INVALID DIRECTION
    }

    method Error {text args} {
	debug.blob/iter {}
	return -code error -errorcode [list BLOB ITER {*}$args] $text
    }

    method API.error {api} {
	debug.blob/iter {}
	my Error "Unimplemented API $api" API MISSING $api
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob::iter 0
return
