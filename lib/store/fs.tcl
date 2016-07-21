# -*- tcl -*-
## (c) 2013-2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## filesystem based blob storage.

# @@ Meta Begin
# Package blob::fs 1
# Meta author      {Andreas Kupries}
# Meta category    Blob storage, database
# Meta description Store blobs in the filesystem
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

debug define blob/fs
debug level  blob/fs
#debug prefix blob/fs {[debug caller] | }
debug prefix blob/fs {} ;# No prefix, arguments can be large

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::fs {
    superclass blob

    # # ## ### ##### ######## #############
    ## State

    variable mybasedir mycounter
    # Name of the directory representing the blob store.

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {dir} {
	my Check exists      $dir "does not exist" MISSING
	my Check isdirectory $dir "expected a directory" FILE
	my Check readable    $dir "not readable" DENIED WRITE
	my Check writable    $dir "not writable" DENIED WRITE

	set mybasedir $dir
	set mycounter 0

	next
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    method PreferedPut {} { return path }

    method TempFile {} {
	while {1} {
	    set result $mybasedir/T-[incr mycounter]-X
	    if {[file exists $result]} continue
	    return $result
	}
    }

    # put-string :- EnterString: uuid, blob --> ()
    method EnterString {uuid content} {
	set dstpath [my P $uuid]
	if {[file exists $dstpath]} return
	file mkdir [file dirname $dstpath]
	fileutil::writeFile -translation binary \
	    $dstpath $content
	return
    }

    # put-file:- EnterFile: uuid, path --> ()
    method EnterFile {uuid path} {
	set dstpath [my P $uuid]
	if {[file exists $dstpath]} return

	file mkdir [file dirname $dstpath]
	if {[catch {
	    # Prefer hard linking, to save on disk space.
	    file link -hard $dstpath $path
	}]} {
	    # But copy if that is not possible, because, for
	    # example the platform does not supporting it, cross
	    # disk linkage, etc.
	    file copy $path $dstpath
	}
	return
    }

    # get-string: uuid --> blob
    method get-string {uuid} {
	my Validate $uuid
	return [my Cat [my P $uuid]]
    }

    # get-channel: uuid --> channel
    method get-channel {uuid} {
	my Validate $uuid
	set path [my P $uuid]
	set chan [open $path r]
	fconfigure $chan -translation binary
	return $chan
    }

    # get-file: uuid --> path
    method get-file {uuid} {
	my Validate $uuid
	set path [my P $uuid]
	set temp [my TempFile]
	try {
	    file link -hard $temp $path
	} on error {e o} {
# See if we can trap on a specific error
puts |$o|
	    file copy -force -- $path $temp
	}

	return $temp
    }

    # names () -> list(uuid)
    method Names {{pattern *}} {
	set r {}
	foreach e [glob -nocomplain -directory $mybasedir -tails */*/$pattern] {
	    lappend r [lindex [file split $e] end]
	}
	return $r
    }

    # exists: uuid -> boolean
    method exists {uuid} {
	file exists [my P $uuid]
    }

    # size () -> integer
    method size {} {
	llength [my names]
    }

    # clear () -> ()
    # Remove all known mappings.
    method clear {} {
	set dirs [glob -nocomplain -directory $mybasedir *]
	if {![llength $dirs]} return
	file delete -force {*}$dirs
	return
    }

    # delete: uuid -> ()
    method delete {uuid} {
	file delete -force [my P $uuid]
	return
    }

    # # ## ### ##### ######## #############
    ## API. Synchronization support

    # # ## ### ##### ######## #############
    ## Internals

    method P {uuid} {
	lappend path $mybasedir
	lappend path [string range $uuid 0 1]
	lappend path [string range $uuid 0 3]
	lappend path $uuid
	file join {*}$path
    }

    method Check {cmd dir text args} {
	if {[file $cmd $dir]} return
	my Error "Bad path $dir, $text" BAD PATH {*}$args
    }

    method PathError {text args} {
	my Error "Bad path $text" BAD PATH {*}$args
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob::fs 0
return
