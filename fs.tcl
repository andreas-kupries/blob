# -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## filesystem based blob storage.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require blob
package require sha1 2

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::fs {
    superclass blob

    # # ## ### ##### ######## #############
    ## State

    variable mybasedir
    # Name of the directory representing the blob store.

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {dir} {
	my Check exists      $dir "does not exist" MISSING
	my Check isdirectory $dir "expected a directory" FILE
	my Check readable    $dir "not readable" DENIED WRITE
	my Check writable    $dir "not writable" DENIED WRITE

	set mybasedir $dir
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    # add: uuid, blob --> ()
    method Enter {uuid content} {
	set dstpath [my P $uuid]
	if {[file exists $dstpath]} return
	file mkdir [file dirname $dstpath]
	fileutil::writeFile -translation binary \
	    $dstpath $content
	return
    }

    # put: uuid, path --> ()
    method EnterPath {uuid path} {
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

    # retrieve: uuid --> blob
    method retrieve {uuid} {
	set path [my P $uuid]
	if {![file exists $path]} {
	    my Error "Expected uuid, got \"$uuid\"" \
		BAD UUID $uuid
	}
	set c [open $path r]
	fconfigure $c -translation binary
	set data [read $c]
	close $c
	return $data
    }

    # channel: uuid --> channel
    method channel {uuid} {
	set path [my P $uuid]
	if {![file exists $path]} {
	    my Error "Expected uuid, got \"$uuid\"" \
		BAD UUID $uuid
	}
	set chan [open $path r]
	fconfigure $chan -translation binary
	return $chan
    }

    # path: uuid --> channel
    method path {uuid} {
	set path [my P $uuid]
	if {![file exists $path]} {
	    my Error "Expected uuid, got \"$uuid\"" \
		BAD UUID $uuid
	}
	return $path
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
