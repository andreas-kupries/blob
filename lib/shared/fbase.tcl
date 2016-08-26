# -*- tcl -*-
## (c) 2013-2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## filesystem based blob storage.

# @@ Meta Begin
# Package blob::fsbase 1
# Meta author      {Andreas Kupries}
# Meta category    Blob storage, database
# Meta description Store blobs in the filesystem, common code
# Meta location    http:/core.tcl.tk/akupries/blob
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     debug
# Meta require     debug::caller
# Meta require     blob
# Meta subject     {blob storage} storage filesystem
# Meta summary     Blob storage
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require blob
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define blob/fs-base
debug level  blob/fs-base
#debug prefix blob/fs-base {[debug caller] | }
debug prefix blob/fs-base {} ;# No prefix, arguments can be large

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::fsbase {
    # # ## ### ##### ######## #############
    ## State

    variable mybasedir mycounter
    # Name of the directory representing the blob store.

    # # ## ### ##### ######## #############
    ## Lifecycle.

    method base {} {
	return $mybasedir
    }

    constructor {dir} {
	my Check exists      $dir "does not exist" MISSING
	my Check isdirectory $dir "expected a directory" FILE
	my Check readable    $dir "not readable" DENIED WRITE
	my Check writable    $dir "not writable" DENIED WRITE

	set mybasedir [file normalize $dir]
	set mycounter 0

	next
	return
    }

    method TempFile {} {
	while {1} {
	    set result $mybasedir/T-[incr mycounter]-X
	    if {[file exists $result]} continue
	    return $result
	}
    }

    method PathOf {uuid} {
	lappend path $mybasedir
	lappend path [string range $uuid 0 1]
	lappend path [string range $uuid 0 3]
	lappend path $uuid
	file join {*}$path
    }

    method Check {cmd dir text args} {
	if {[file $cmd $dir]} return
	my PathError "$dir, $text" {*}$args
    }

    method PathError {text args} {
	my Error "Bad path $text" BAD PATH {*}$args
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob::fsbase 0
return
