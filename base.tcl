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
package require sha1 2            ; # tcllib
package require fileutil          ; # tcllib

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob {
    # # ## ### ##### ######## #############
    ## API. Virtual methods. Implementation required.

    # add: blob --> uuid
    method add {blob} { my APIerror add }

    # put: path --> uuid
    method put {path} { my APIerror put }

    # retrieve: uuid --> blob
    method retrieve {uuid} { my APIerror retrieve }

    # channel: uuid --> channel
    method channel {uuid} { my APIerror channel }

    # names: () -> list (uuid)
    method names {}  { my APIerror names }

    # exists: uuid -> boolean
    method exists {uuid} { my APIerror exists }

    # size () -> integer
    method size {} { my APIerror size }

    # clear () -> ()
    method clear {} { my APIerror clear }

    # # ## ### ##### ######## #############
    ## API. Convenience method to add a file to the store.
    ## Re-implement for efficiency (link, copy, ...).

    # # ## ### ##### ######## #############
    ## Internal helpers

    method Uuid.blob {blob} {
	sha1::sha1 -hex $blob
    }

    method Uuid.path {path} {
	sha1::sha1 -hex -file $path
    }

    method Cat {path} {
	fileutil::cat -translation binary $path
    }

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
