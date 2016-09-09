# -*- tcl -*-
## (c) 2013-2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## Statistics for blobs.
## Instead of storing the entered blobs just count statistics
## (#blobs, #entered files, total size, min, max, average)

# @@ Meta Begin
# Package blob::statistics 1
# Meta author      {Andreas Kupries}
# Meta category    Blob storage, statistics
# Meta description Blobs statistics
# Meta location    http:/core.tcl.tk/akupries/blob
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     debug
# Meta require     debug::caller
# Meta require     blob
# Meta require     tcl::chan::string
# Meta subject     {blob statistics} statistics
# Meta subject     ?
# Meta summary     Blob statistics
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require blob
package require tcl::chan::string ; # tcllib
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define blob/statistics
debug level  blob/statistics
#debug prefix blob/statistics {[debug caller] | }
debug prefix blob/statistics {} ;# No prefix, arguments can be large

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::statistics {
    superclass blob

    # # ## ### ##### ######## #############
    ## State

    variable mycount mysize mymin mymax myentered mystored
    # mycount:   dict (uuid -> count)
    # mysize:    dict (uuid -> size)
    # mymin:     int
    # mymax:     int
    # myentered: int
    # mystored:  int

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {} {
	my clear
	next
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    method PreferedPut {} { return string }

    # put-string :- EnterString: uuid, blob --> ()
    method EnterString {uuid blob} {
	set myentered {}
	set mystored  {}

	if {[dict exists $mycount $uuid]} {
	    dict incr mycount $uuid
	    return
	}

	set size [string length $blob]
	dict set mycount $uuid 1
	dict set mysize  $uuid $size

	if {$size > $mymax} { set mymax $size }
	if {$size < $mymin} { set mymin $size }
	return
    }

    # put-file:- EnterFile: path --> ()
    method EnterFile {uuid path} {
	set myentered {}
	set mystored  {}

	if {[dict exists $mycount $uuid]} {
	    dict incr mycount $uuid
	    return
	}

	set size [file size $path]
	dict set mycount $uuid 1
	dict set mysize  $uuid $size

	if {$size > $mymax} { set mymax $size }
	if {$size < $mymin} { set mymin $size }
	return
    }

    # get-string: uuid --> blob
    method get-string {uuid} {
	my Validate $uuid
	return [dict get $mycount $uuid]
    }

    # get-channel: uuid --> channel
    method get-channel {uuid} {
	my Validate $uuid
	return [tcl::chan::string [dict get $mycount $uuid]]
    }

    # names () -> list(uuid)
    method Names {{pattern *}} {
	dict keys $mycount $pattern
    }

    # exists: string -> boolean
    method exists {uuid} { dict exists $mycount $uuid }

    # size () -> integer
    method size {} { dict size $mycount }

    # clear () -> ()
    method clear {} {
	set mycount   {}
	set mysize    {}
	set mymin     Inf
	set mymax     0
	set myentered {}
	set mystored  {}
	return
    }

    # delete: uuid -> ()
    method remove {uuid} {
	dict unset mycount $uuid
	dict unset mysize  $uuid
	return
    }

    # # ## ### ##### ######## #############
    ## Special methods to query the statistics.

    method min {} { return $mymin }
    method max {} { return $mymax }

    method bytes-entered {} {
	if {$myentered ne {}} { return $myentered }
	set myentered 0
	dict for {k count} $mycount {
	    incr myentered [expr {$count * [dict get $mysize $k]}]
	}
	return $myentered
    }

    method bytes-stored {} {
	if {$mystored ne {}} { return $mystored }
	set mystored 0
	dict for {k count} $mycount {
	    incr mystored [dict get $mysize $k]
	}
	return $mystored
    }

    method average {} {
	expr {[my bytes-stored] / [dict size $mycount]}
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob::statistics 0
return
