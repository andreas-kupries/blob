# -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## In-memory blob storage.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require blob
package require tcl::chan::string ; # tcllib

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::memory {
    superclass blob

    # # ## ### ##### ######## #############
    ## State

    variable mystore
    # mystore: dict (uuid -> blob)

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {} { my clear }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    # add: blob --> uuid
    method add {blob} {
	set uuid [my Uuid.blob $blob]
	if {![dict exists $mystore $uuid]} {
	    dict set mystore $uuid $blob
	}
	return $uuid
    }

    # put: blob --> uuid
    method put {path} {
	set uuid [my Uuid.path $path]
	if {![dict exists $mystore $uuid]} {
	    dict set mystore $uuid [my Cat $path]
	}
	return $uuid
    }

    # retrieve: uuid --> blob
    method retrieve {uuid} {
	my Validate $uuid
	return [dict get $mystore $uuid]
    }

    # channel: uuid --> channel
    method channel {uuid} {
	my Validate $uuid
	return [tcl::chan::string [dict get $mystore $uuid]]
    }

    # names () -> list(uuid)
    method names {} { dict keys $mystore }

    # exists: string -> boolean
    method exists {uuid} { dict exists $mystore $uuid }

    # size () -> integer
    method size {} { dict size $mystore }

    # clear () -> ()
    method clear {} {
	set mystore {}
	return
    }

    # delete: uuid -> ()
    method delete {uuid} {
	dict unset mystore $uuid
	return
    }

    # # ## ### ##### ######## #############

    method Validate {uuid} {
	if {[dict exists $mystore $uuid]} return
	my Error "Expected uuid, got \"$uuid\"" \
	    BAD UUID $uuid
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob::memory 0
return
