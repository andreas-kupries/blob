# -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## option handling - constructor-only (for the moment)

# @@ Meta Begin
# Package blob::option 0
# Meta author      {Andreas Kupries}
# Meta category    Blob storage
# Meta description Internal support package, option handling for instance constructors
# Meta location    http:/core.tcl.tk/akupries/blob
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     debug
# Meta require     debug::caller
# Meta subject     {option handling} {get option}
# Meta summary     Option support
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define blob/option
debug level  blob/option
debug prefix blob/option {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::option {
    # # ## ### ##### ######## #############
    ## State

    variable mydef myvalue
    # mydef   :: dict (option name -> default)
    # myvalue :: dict (option name -> value)

    # # ## ### ##### ######## #############
    ## Accessor

    method cget {name} {
	debug.blob/option {}
	my Validate $name
	return [dict get $myvalue $name]
    }

    method configure {args} {
	debug.blob/option {}
	my configure-list $args
	return
    }

    method configure-list {words} {
	debug.blob/option {}
	foreach {option value} $words {
	    my Validate $option
	    dict set myvalue $option $value
	}
	return
    }

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {spec} {
	debug.blob/option {}
	my Init
	foreach def $spec { my Def {*}$def }
	return
    }

    method Init {} {
	debug.blob/option {}
	set mydef   {}
	set myvalue {}
	return
    }

    method Def {name default} {
	# FUTURE: option info like type, default, validation, required, cons-only, etc.
	debug.blob/option {}
	if {[dict exists $mydef $name]} {
	    my Error "Unknown option \"$name\"" DUPLICATE
	}
	dict set mydef   $name .
	dict set myvalue $name $default
	return
    }

    # # ## ### ##### ######## #############

    method Validate {name} {
	debug.blob/option {}
	if {[dict exists $mydef $name]} return
	my Error "Unknown option \"$name\"" INVALID
    }

    method Error {text args} {
	debug.blob/option {}
	return -code error -errorcode [list BLOB OPTION {*}$args] $text
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob::option 0
return
