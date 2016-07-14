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

    # names: ?pattern?... --> list (uuid)
    method names {args}  {
	if {![llength $args]} {
	    return [my Names]
	}
	set r {}
	foreach pattern $args {
	    lappend r {*}[my Names $pattern]
	}
	return $r
    }
    method Names {{pattern *}} { my API.error Names }

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
	set uuidlist [$src names {*}$uuidlist]
	foreach uuid $uuidlist {
	    if {[my exists $uuid]} continue
	    my AddVerify $uuid [$src channel $uuid]
	}
	return
    }

    method ihave-for-path {uuidlist src} {
	set uuidlist [$src names {*}$uuidlist]
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
    ## Push (self to other). Asynchronous.

    # We are self in a push operation.
    method push-async {donecmd destination {uuidlist *}} {
	# Delegating to the peer for actual control of the operation.
	# The peer will use either 'path' or 'channel' methods to gain
	# access to the blobs to transfer.
	if {[my HasPath]} {
	    $destination ihave-async-path $donecmd $uuidlist [self]
	} else {
	    $destination ihave-async-chan $donecmd $uuidlist [self]
	}
	return
    }

    # We are the peer in a push operation, and have to pull blobs from
    # the source. Two entry-points, depending on the retrieval API the
    # source is able to provide. We ignore the blobs we already
    # have/know.

    method ihave-async-chan {donecmd uuidlist src} {
	my IHaveAsyncChan $donecmd [$src names {*}$uuidlist] $src
	return
    }

    method IHaveAsyncChan {donecmd uuidlist src} {
	while {[llength $uuidlist]} {
	    set uuidlist [lassign $uuidlist uuid]
	    if {[my exists $uuid]} continue
	    my AddVerify $uuid [$src channel $uuid]

	    after 0 [mymethod IHaveAsyncChan $donecmd $uuidlist $src]
	    return
	}
	after 0 $donecmd
	return
    }

    method ihave-async-path {donecmd uuidlist src} {
	my IHaveAsyncPath $donecmd [$src names {*}$uuidlist] $src
	return
    }

    method IHaveAsyncPath {donecmd uuidlist src} {
	while {[llength $uuidlist]} {
	    set uuidlist [lassign $uuidlist uuid]
	    if {[my exists $uuid]} continue
	    my PutVerify $uuid [$src path $uuid]

	    after 0 [mymethod IHaveAsyncPath $donecmd $uuidlist $src]
	    return
	}
	after 0 $donecmd
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
	if {![llength $uuidlist]} return
	$origin iwant $uuidlist [self]
	return
    }

    # We are the peer in a pull operation and have to push blobs into
    # the destination.
    method iwant {uuidlist destination} {
	# Split by (non-)support of 'path' lookup.
	# If we have 'path' we can avoid

	set uuidlist [my names {*}$uuidlist]
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

    # # ## ### ##### ######## #############
    ## Pull (self from other). Asynchronous.

    # We are self in a pull operation.
    method pull-async {donecmd origin {uuidlist *}} {
	# Delegating to the peer for actual control of the operation.
	# The peer will use either 'put' or 'add' methods to enter
	# the blobs to transfer.
	if {![llength $uuidlist]} {
	    after 0 $donecmd
	    return
	}
	$origin iwant-async $donecmd $uuidlist [self]
	return
    }

    # We are the peer in a pull operation and have to push blobs into
    # the destination.
    method iwant-async {donecmd uuidlist destination} {
	# Split by (non-)support of 'path' lookup.
	# If we have 'path' we can avoid

	set uuidlist [my names {*}$uuidlist]
	if {[my HasPath]} {
	    my IwantPut $donecmd $uuidlist $destination
	} else {
	    my IwantChan $donecmd $uuidlist $destination
	}
	return
    }

    method IwantPut {donecmd uuidlist destination} {
	while {[llength $uuidlist]} {
	    set uuidlist [lassign $uuidlist uuid]
	    if {[$destination exists $uuid]} continue
	    $destination put [my path $uuid]

	    after 0 [mymethod IwantPut $donecmd $uuidlist $destination]
	    return
	}
	after 0 $donecmd
	return
    }

    method IwantChan {donecmd uuidlist destination} {
	while {[llength $uuidlist]} {
	    set uuidlist [lassign $uuidlist uuid]
	    if {[$destination exists $uuid]} continue

	    # Optimize: enter from channel?  Not really. Would
	    # just move the common code below into the derived
	    # classes.

	    set channel [my channel $uuid]
	    set blob    [read $channel]
	    close       $channel

	    $destination add $blob

	    after 0 [mymethod IwantChan $donecmd $uuidlist $destination]
	    return
	}
	after 0 $donecmd
	return
    }

    # # ## ### ##### ######## #############
    # Sync (self push/pull to/from other). Synchronous.

    # The initiator, self, delegates the action to the peer for actual
    # control and execution of the operation (methods
    # iexchange-*). The method chosen by self encodes whether it
    # supports the 'path' retrieval operation or only the standard
    # 'channel' retriever. The peer uses this information to optimize
    # the blob transfer, i.e. chooses the API with which it retrieves
    # the blob. The default implementations of the peer/ihave-* follow
    # the hint given by the initiator. Filtering the uuid list happens
    # only in the peer, as the only side knowing which blobs it is
    # missing.

    method sync {peer {uuidlist *}} {
	# Delegating to the peer for actual control of the operation.
	# The peer will use either 'path' or 'channel' methods to gain
	# access to the blobs to transfer.
	if {[my HasPath]} {
	    $peer iexchange-for-path $uuidlist [self]
	} else {
	    $peer iexchange-for-chan $uuidlist [self]
	}
	return
    }

    # We are the peer in a sync operation, and have to push and pull
    # blobs to and from the source. Two entry-points, depending on the
    # retrieval API the source is able to provide. We ignore the blobs
    # we already have/know. Internally we call on the existing APIs
    # for pushing and pulling.

    method iexchange-for-chan {uuidlist peer} {
	my ihave-for-chan $uuidlist $peer
	my iwant          $uuidlist $peer
	return
    }

    method iexchange-for-path {uuidlist peer} {
	my ihave-for-path $uuidlist $peer
	my iwant          $uuidlist $peer
	return
    }

    # # ## ### ##### ######## #############
    ## Sync. Asynchronous.

    method sync-async {donecmd peer {uuidlist *}} {
	# Delegating to the peer for actual control of the operation.
	# The peer will use either 'path' or 'channel' methods to gain
	# access to the blobs to transfer.
	if {[my HasPath]} {
	    $peer iexchange-async-path $donecmd $uuidlist [self]
	} else {
	    $peer iexchange-async-chan $donecmd $uuidlist [self]
	}
	return
    }

    method iexchange-async-chan {donecmd uuidlist peer} {
	# donecmd - generate a merger triggering done only when both
	# parts completed.

	set n $exchcounter
	variable merge$n 2
	set donecmd [mymethod IExchDone n $donecmd]

	my ihave-async-chan $donecmd $uuidlist $peer
	my iwant-async      $donecmd $uuidlist $peer
	return
    }

    method iexchange-async-path {donecmd uuidlist peer} {
	# donecmd - generate a merger triggering done only when both
	# parts completed.

	set n $exchcounter
	variable merge$n 2
	set donecmd [mymethod IExchDone n $donecmd]

	my ihave-async-path $donecmd $uuidlist $peer
	my iwant-async      $donecmd $uuidlist $peer
	return
    }

    method IExchDone {id donecmd} {
	variable merge$id
	upvar 0 merge$id mergecount

	incr mergecount -1
	if {$mergecount > 0} return
	unset merge$id

	after 0 $donecmd
	return
    }

    variable exchcounter

    constructor {} {
	set exchcounter 0
	return
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
