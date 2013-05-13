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
    method add {blob} {
	set uuid  [my Uuid.blob $blob]
	my Enter $uuid $blob
	return $uuid
    }

    # put: path --> uuid
    method put {path} {
	set uuid [my Uuid.path $path]
	my EnterPath $uuid $path
	return $uuid
    }

    method Enter     {uuid blob} { my API.error Enter }
    method EnterPath {uuid path} { my API.error EnterPath }

    # retrieve: uuid --> blob		[validate uuid]
    method retrieve {uuid} { my API.error retrieve }

    # channel: uuid --> channel		[validate uuid]
    method channel {uuid} { my API.error channel }

    # names: ?pattern? --> list (uuid)
    method names {{pattern *}}  { my API.error names }

    # exists: uuid --> boolean
    method exists {uuid} { my API.error exists }

    # size: () --> integer
    method size {} { my API.error size }

    # clear: () --> ()
    method clear {} { my API.error clear }

    # delete: uuid --> ()
    method delete {} { my API.error delete }

    # # ## ### ##### ######## #############
    ## API. Methods for uni- and bi-directional
    ##      synchronization (push, pull, and sync).
    ##      Limited sync possible

    # TODO: async operation.

    # # ## ### ##### ######## #############
    ## Push (self to other). Synchronous.

    # The initiator, self, delegates the action to the peer for actual
    # control and execution of the operation (methods ihave-*). The
    # method chosen by self encodes whether it supports the 'path'
    # retrieval operation or only the standard 'channel'
    # retriever. The peer uses this information to optimize the blob
    # transfer, i.e. chooses the API with which it retrieves the
    # blob. The default implementations of the peer/ihave-* follow the
    # hint given by the initiator. Filtering the uuid list happens
    # only in the peer, as the only side knowing which blobs it is
    # missing.

    # We are self in a push operation.
    method push {destination {uuidlist *}} {
	# Delegating to the peer for actual control of the operation.
	# The peer will use either 'path' or 'channel' methods to gain
	# access to the blobs to transfer.
	set uuidlist [my Expand $uuidlist]
	if {![llength $uuidlist]} return
	if {[my HasPath]} {
	    $destination ihave-for-path $uuidlist [self]
	} else {
	    $destination ihave-for-chan $uuidlist [self]
	}
	return
    }

    # We are the peer in a push operation, and have to pull blobs from
    # the source. Two entry-points, depending on the retrieval API the
    # source is able to provide. We ignore the blobs we already
    # have/know.

    method ihave-for-chan {uuidlist src} {
	foreach uuid $uuidlist {
	    if {[my exists $uuid]} continue
	    my AddVerify $uuid [$src channel $uuid]
	}
	return
    }

    method ihave-for-path {uuidlist src} {
	foreach uuid $uuidlist {
	    if {[my exists $uuid]} continue
	    my PutVerify $uuid [$src path $uuid]
	}
	return
    }

    method AddVerify {uuid channel} {
	set blob [read $channel]
	close $channel
	set actual_uuid [my Uuid.blob $blob]
	if {$uuid ne $actual_uuid} {
	    my XFER.error $uuid $actual_uuid
	}
	my Enter $uuid $blob
	return
    }

    method PutVerify {uuid path} {
	set actual_uuid [my Uuid.path $path]
	if {$uuid ne $actual_uuid} {
	    my XFER.error $uuid $actual_uuid
	}
	my EnterPath $uuid $path
	return
    }

    # # ## ### ##### ######## #############
    ## Pull (self from other). Synchronous.

    # The initiator, self, delegates the action to the peer for actual
    # control and execution of the operation (method iwant). The peer
    # can use the standard APIs (add, put) to enter the blobs with the
    # requested uuids. The peer is free to choose. The standard
    # implementation of the peer (iwant) uses 'put' if it supports the
    # 'path' retrieval operation, and 'add' otherwise, for optimal
    # transfer. The pattern list is filtered in the peer, as the only
    # one knowing what it has. The peer does also filter against the
    # initiator as it has the uuid and thus can do it trivially before
    # a transfer, and thus avoid transfering duplicates. Overall this
    # means that 'pull' may not receive all blobs it requested, as the
    # peer may not have them.

    # We are self in a pull operation.
    method pull {origin {uuidlist *}} {
	# Delegating to the peer for actual control of the operation.
	# The peer will use either 'put' or 'add' methods to enter
	# the blobs to transfer.
	#set uuidlist [my Filter [my Expand $uuidlist]]
	if {![llength $uuidlist]} return
	$origin iwant $uuidlist [self]
	return
    }

    # We are the peer in a pull operation and have to push blobs into
    # the destination.
    method iwant {uuidlist destination} {
	# Split by (non-)support of 'path' lookup.
	# If we have 'path' we can avoid

	set uuidlist [my Expand $uuidlist]
	if {[my HasPath]} {
	    foreach uuid $uuidlist {
		if {[$destination exists $uuid]} continue
		$destination put [my path $uuid]
	    }
	} else {
	    foreach uuid $uuidlist {
		if {[$destination exists $uuid]} continue

		# Optimize: enter from channel?  Not really. Would
		# just move the common code below into the derived
		# classes.

		set channel [my channel $uuid]
		set blob    [read $channel]
		close       $channel

		$destination add $blob
	    }
	}
	return
    }


    if 0 {
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

    # Can be overriden for performance.
    method Filter {uuidlist} {
	set r {}
	foreach uuid $uuidlist {
	    if {[my exists $uuid]} continue
	    lappend r $uuid
	}
	return $r
    }

    # # ## ### ##### ######## #############
    ## Internal helpers

    method HasPath {} {
	expr {"path" in [info object methods [self] -all]}
    }

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

    method API.error {api} {
	my Error "Unimplemented API $api" API MISSING $api
    }

    method XFER.error {expected actual} {
	my Error "Transfer uuid mismatch, expected $expected, got $actual" \
	    XFER MISMATCH $expected $actual
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob 0
return
