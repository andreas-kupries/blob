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

    # add: blob --> uuid
    method add {blob} {
	set uuid [my Uuid.blob $blob]
	set dstpath [my P $uuid]
	if {![file exists $dstpath]} {
	    file mkdir [file dirname $dstpath]
	    fileutil::writeFile -translation binary \
		$dstpath $blob
	}
	return $uuid
    }

    # put: path --> uuid
    method put {path} {
	set uuid    [my Uuid.path $path]
	set dstpath [my P $uuid]
	if {![file exists $dstpath]} {
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
	}
	return $uuid
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

    # retrieve: uuid --> channel
    method channel {uuid} {
	set path [my P $uuid]
	if {![file exists $path]} {
	    my Error "Expected uuid, got \"$uuid\"" \
		BAD UUID $uuid
	}
	return [open $path r]
    }

    # names () -> list(uuid)
    method names {} {
	set r {}
	foreach e [glob -nocomplain -directory $mybasedir -tails */*/*] {
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
