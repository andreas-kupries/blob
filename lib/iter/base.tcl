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
# Meta category    Blob storage iterator
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
## TODOs

# - Investigate ways of creating a deeper association between blob
#   stores and iterators over them. Mainly to ensure that all blobs in
#   a store have a value for the iterator properties, and none is
#   forgotten.

# # ## ### ##### ######## ############# #####################
##
# Notes:
#
# - An iterator stores, conceptually, a blob property by which blobs
#   can be sorted and then iterated over in the resulting order.
#
#   As such each blob in the iterator has at most one property value
#   associated with it, while converserly, a single property value may
#   have multiple blobs associated with it.
#
#   In a sense the iterator is a table parallel to the blob-table, a
#   sibling with the same primary key, the blob uuid. The 'at most' in
#   the previous paragraph means that this table can have NULL values
#   for the property column, although actually the entry will simply
#   not exist.
#
# - For the sorting, done by the property value, and iteration this
#   means that the position of the cursor is fully specified by the
#   'value' we are at, plus the 'uuid' under that value.
#
#   Note that while uuids are unique, the values are not. We can have
#   multiple entries with the same value, and different uuids. That is
#   why the cursor position requires the uuid as well, to disambiguate
#   between entries with the same value.
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

    # add: (uuid property_value) --> ()
    # Extend iterator with new element
    method add {uuid property_value} {
	debug.blob/iter {}
	my ValidateUnknownUUID $uuid
	my Add $uuid $property_value
	return
    }

    method Add {uuid property_value} { my API.error Add }

    # remove: (uuid...) --> ()
    # Take element out of the iterator
    method remove {uuid args} {
	debug.blob/iter {}
	foreach uuid [linsert $args 0 $uuid] {
	    if {![my exists $uuid]} {
		debug.blob/iter {not found, ignored}
		continue
	    }
	    # If the removed entry is for the current cursor location
	    # we move forward to the location after the removed entry
	    # in the chosen direction. This prevents the iterator from
	    # possibly pointing to an invalid location after the
	    # removal. It also means that the actual implementation of
	    # Remove does not have to care about this possibility.
	    if {[my IsCurrent $uuid]} {
		my next 1
	    }
	    my Remove $uuid
	}
	return
    }

    method Remove {uuid} { my API.error Remove }

    method IsCurrent {uuid} { my API.error IsCurrent }

    # clear: () --> ()
    # Shrink iterator to nothing
    method clear {} { my API.error clear }

    # data!: (list(tuple(uuid,property_value)) --> ()
    # Load iterator with bulk data (bulk add)
    method data! {tuples} {
	debug.blob/iter {}
	# Validate data first, ...
	foreach pair $tuples {
	    set uuid [lindex $pair 0]
	    my ValidateUnknownUUID $uuid
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
    #     pair('at',pair(property_value,uuid))
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

    # get: (uuid) --> property_value
    # Get value for uuid
    method get {uuid} {
	debug.blob/iter {}
	my ValidateUUID $uuid
	return [my Get $uuid]
    }

    method Get {uuid} { my API.error Get }

    # exists: (uuid) -> bool
    # Check if uuid is already known
    method exists {uuid} { my API.error exists }

    # size: () --> int
    # Return number of entries in the index
    method size {} { my API.error size }

    # at: length --> list(tuple(uuid,property_value))
    # Return elements of the index at the cursor position.
    method at {n} { my API.error at }

    # direction: () -> string
    # Query cursor for its direction
    method direction {} { my API.error direction }

    # location: () -> pair('start',{})
    #              -> pair('end',{})
    #              -> pair('at',pair(property_value,uuid))
    # Query cursor for current position.
    method location {} { my API.error location }

    # data: () -> list(tuple(uuid,property_value))
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

    method ValidateUUID {uuid} {
	if {[my exists $uuid]} return
	my Error "Unknown UUID \"$uuid\"" UUID UNKNOWN
    }

    method ValidateUnknownUUID {uuid} {
	if {![my exists $uuid]} return
	my Error "Duplicate UUID \"$uuid\"" UUID DUPLICATE
    }

    method Error {text args} {
	debug.blob/iter {}
	return -code error -errorcode [list BLOB ITER {*}$args] $text
    }

    method API.error {api} {
	debug.blob/iter {}
	my Error "Unimplemented API $api" API MISSING $api
    }

    # Debug helper. Show entire iterator table, plus the location of
    # the cursor.
    method /SHOW {} {
	set k 0
	set r {}

	set data [lsort -index 1 [lsort -index 0 [my data]]]
	lassign [my location] ctype cdetail

	switch -exact -- $ctype {
	    start {
		lappend r "* --- start"
		foreach item $data  {
		    lassign $item uuid pval
		    lappend r [format "  %3d %10s %s" $k $pval $uuid]
		    incr k
		}
	    }
	    end {
		foreach item $data {
		    lassign $item uuid pval
		    lappend r [format "  %3d %10s %s" $k $pval $uuid]
		    incr k
		}
		lappend r "* --- end"
	    }
	    at {
		set pre 1
		lassign $cdetail cpval cuuid
		foreach item $data {
		    lassign $item uuid pval
		    if {($pval eq $cpval) && ($uuid eq $cuuid)} {
			# Found cursor exactly
			set mark *
			set pre 0
		    } else {
			set mark { }
		    }
		    if {$pre &&
			((($pval eq $cpval) &&
			  ([string compare $uuid $cuuid] > 0)) ||
			 ([string compare $pval $cpval] > 0))} {
			# First time beyond cursor, show where it is missing.
			# Should not happen.
			lappend r [format "* --- %10s %s" $cpval $cuuid]
			set pre 0
		    }
		    lappend r [format "%s %3d %10s %s" $mark $k $pval $uuid]
		    incr k
		}
	    }
	}
	return [join $r \n]\n
    }
    #export /SHOW

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob::iter 0
return
