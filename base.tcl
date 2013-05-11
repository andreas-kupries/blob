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
package require oo::util          ; # tcllib

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob {
    # # ## ### ##### ######## #############
    ## API. Virtual methods. Implementation required.

    # add: blob --> uuid
    method add {blob} { my APIerror add }

    # put: path --> uuid
    method put {path} { my APIerror put }

    # retrieve: uuid --> blob		[validate uuid]
    method retrieve {uuid} { my APIerror retrieve }

    # channel: uuid --> channel		[validate uuid]
    method channel {uuid} { my APIerror channel }

    # names: ?pattern? --> list (uuid)
    method names {{pattern *}}  { my APIerror names }

    # exists: uuid --> boolean
    method exists {uuid} { my APIerror exists }

    # size: () --> integer
    method size {} { my APIerror size }

    # clear: () --> ()
    method clear {} { my APIerror clear }

    # delete: uuid --> ()
    method delete {} { my APIerror delete }

    # # ## ### ##### ######## #############
    ## API. Methods for uni- and bi-directional
    ##      synchronization (push, pull, and sync).
    ##      Limited sync possible

    # TODO: async operation.

    method push {destination {uuidlist *}} {
	# Look at the Fossil Transfer protocol.
	$destination ihave [my Expand $uuidlist] \
	    [oo::callback channel]
	# Might need a done-callback (async).
	return
    }

    method ihave {uuidlist pullcmd} {
	foreach uuid $uuidlist {
	    if {[my exists $uuid]} continue
	    my Push $uuid [{*}$pullcmd $uuid]
	}
	# Definitely need done-callback (async)
	return
    }

    method pull {origin {uuidlist *}} {
	# Look at the Fossil Transfer protocol.
	# Allow async operation
	$destination iwant [my Expand $uuidlist] \
	    [oo::callback Push]
	# Might need a done-callback (async)
	return
    }

    method iwant {uuidlist pushcmd} {
	foreach uuid $uuidlist {
	    if {![my exists $uuid]} continue
	    {*}$pushcmd [my channel $uuid]
	}
	# Definitely need a done-callback (async)
	return
    }

    method sync {peer {uuidlist *}} {
	# Look at the Fossil Transfer protocol.
	# Allow async operation
	#set uuidlist [my Expand $uuidlist]
	#$peer ihave $uuidlist [oo::callback Pull]
	#$peer iwant $ [oo::callback Push]
	# Interleave push/pull for optimal operation.
	# Might need a done-callback
	return
    }

    # # ## ### ##### ######## #############
    ## Internal sync helpers

    method Expand {uuidlist} {
	set r {}
	foreach pattern $uuidlist {
	    lappend r {*}[my names $pattern]
	}
	return $r
    }

    method Push {uuid channel} {
	# Invoked by origin store during a pull, to hand us (the
	# destination) a blob to save, as read-only channel. We are
	# responsible for reading the data and closing the channel.
	my add-verify $uuid [read $channel]
	close $channel
	return
    }

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
