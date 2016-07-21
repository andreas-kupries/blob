# -*- tcl -*-
## (c) 2013-2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## In-memory blob storage.

# @@ Meta Begin
# Package blob::memory 1
# Meta author      {Andreas Kupries}
# Meta category    Blob storage, database
# Meta description Keep blobs in memory
# Meta location    http:/core.tcl.tk/akupries/blob
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     debug
# Meta require     debug::caller
# Meta require     blob
# Meta require     tcl::chan::string
# Meta subject     {blob storage} storage memory
# Meta subject     ?
# Meta summary     Blob storage
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

debug define blob/memory
debug level  blob/memory
#debug prefix blob/memory {[debug caller] | }
debug prefix blob/memory {} ;# No prefix, arguments can be large

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
	if {[dict exists $mystore $uuid]} return
	dict set mystore $uuid $blob
	return
    }

    # put-file:- EnterFile: path --> ()
    method EnterFile {uuid path} {
	if {[dict exists $mystore $uuid]} return
	dict set mystore $uuid [my Cat $path]
	return
    }

    # get-string: uuid --> blob
    method get-string {uuid} {
	my Validate $uuid
	return [dict get $mystore $uuid]
    }

    # get-channel: uuid --> channel
    method get-channel {uuid} {
	my Validate $uuid
	return [tcl::chan::string [dict get $mystore $uuid]]
    }

    # names () -> list(uuid)
    method Names {{pattern *}} {
	dict keys $mystore $pattern
    }

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
}

# # ## ### ##### ######## ############# #####################
package provide blob::memory 0
return
