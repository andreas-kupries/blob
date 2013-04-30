# -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## Base class for associative blob storage.
##
## This class declares the API all actual classes have to
## implement. It also provides standard APIs for the
## de(serialization) of blob stores.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob {
    # # ## ### ##### ######## #############
    ## API. Virtual methods. Implementation required.

    # add: blob --> uuid
    method add {blob} { my APIerror add }

    # retrieve: uuid --> blob		[validate uuid]
    method retrieve {uuid} { my APIerror retrieve }

    # channel: uuid --> channel		[validate uuid]
    method channel {uuid} { my APIerror channel }

    # names: () --> list (uuid)
    method names {}  { my APIerror names }

    # exists: uuid --> boolean
    method exists {uuid} { my APIerror exists }

    # size: () --> integer
    method size {} { my APIerror size }

    # clear: () --> ()
    method clear {} { my APIerror clear }

    # # ## ### ##### ######## #############
    ## Internal helpers

    method Error {text args} {
	return -code error -errorcode [list BLOB {*}$args] $text
    }

    method APIerror {api} {
	my Error "Unimplemented API $api" API MISSING $api
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob 0
return
