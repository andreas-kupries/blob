# -*- tcl -*-
## (c) 2013-2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## Base class for associative blob storage.
##
## This class declares the API all actual storage classes have to
## implement. It also provides standard APIs for the de(serialization)
## of blob stores.

# @@ Meta Begin
# Package blob 1
# Meta author      {Andreas Kupries}
# Meta category    Blob storage, database
# Meta description Base class for blob stores
# Meta location    http:/core.tcl.tk/akupries/blob
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     debug
# Meta require     debug::caller
# Meta require     fileutil
# Meta require     oo::util
# Meta require     sha1
# Meta subject     {blob storage} storage
# Meta summary     Blob storage
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require sha1 2            ; # tcllib
package require fileutil          ; # tcllib
package require oo::util          ; # tcllib
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define blob
debug level  blob
#debug prefix blob {[debug caller] | }
debug prefix blob {} ;# No prefix, arguments can be large

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob {
    # # ## ### ##### ######## #############
    ## Lifecycle

    variable myexchcounter myisnew

    constructor {} {
	debug.blob {[debug caller] | }
	set myexchcounter 0
	set myisnew no
	return
    }

    # # ## ### ##### ######## #############
    ## API.

    # put-string: blob --> uuid		[generic]
    method put-string {blob} {
	debug.blob {[lreplace [info level 0] end end <BLOB:[string length $blob]>]}
	set uuid  [my Uuid.blob $blob]
	set myisnew [my EnterString $uuid $blob]

	debug.blob {[debug caller] | ==> ($uuid)}
	return $uuid
    }

    # put-file: path --> uuid
    method put-file {path} {
	debug.blob {[debug caller] | }
	set uuid [my Uuid.path $path]
	set myisnew [my EnterFile $uuid $path]

	debug.blob {[debug caller] | ==> ($uuid)}
	return $uuid
    }

    # put-channel: channel --> uuid
    method put-channel {chan} {
	debug.blob {[debug caller] | }
	set blob [read $chan]
	set uuid  [my Uuid.blob $blob]
	set myisnew [my EnterString $uuid $blob]

	debug.blob {[debug caller] | ==> ($uuid)}
	return $uuid
    }

    # new: () --> boolean
    method new {} {
	debug.blob {[debug caller] | ==> ($myisnew)}
	return $myisnew
    }

    # get-string: uuid --> blob		[validate uuid][abstract]
    method get-string {uuid} {
	my API.error get-string
    }

    # get-channel: uuid --> channel	[caller has to close it]
    method get-channel {uuid} {
	debug.blob {[debug caller] | }
	set result [tcl::chan::string [my get-string $uuid]]

	debug.blob {[debug caller] | ==> ($result)}
	return $result
    }

    # get-file: uuid --> path		[caller has to delete]
    method get-file {uuid} {
	debug.blob {[debug caller] | }
	set path [my TempFile]
	fileutil::writeFile -translation binary $path [my get-string $uuid]

	debug.blob {[debug caller] | ==> ($path)}
	return $path
    }

    # store-to-file: uuid path --> ()
    method store-to-file {uuid path} {
	debug.blob {[debug caller] | }
	file rename [my get-file $uuid] $path

	debug.blob {[debug caller] | /done}
	return
    }

    # remove: uuid --> ()		[validate uuid][abstract]
    method remove {uuid} { my API.error remove }

    # clear: () --> ()			[abstract]
    method clear {} { my API.error clear }

    # size: () --> integer		[abstract]
    method size {} { my API.error size }

    # names: ?pattern?... --> list (uuid)
    method names {args}  {
	debug.blob {[debug caller] | }
	if {![llength $args]} {
	    set result [my Names]
	} else {
	    set result {}
	    foreach pattern $args {
		lappend result {*}[my Names $pattern]
	    }
	}

	debug.blob {[debug caller] | ==> ($result)}
	return $result
    }

    # exists: uuid --> boolean		[abstract]
    method exists {uuid} { my API.error exists }

    # # ## ### ##### ######## #############

    # PreferedPut: () --> {path, chan, string}
    method PreferedPut {} { my API.error PreferedPut }

    method TempFile {} {
	return [fileutil::tempfile]
    }

    # # ## ### ##### ######## #############
    ## API. Abstract methods used in the generic code
    ## above. Implementation required.

    # EnterString: uuid blob --> bool
    method EnterString {uuid blob} { my API.error EnterString }

    # EnterFile: uuid path --> bool
    method EnterFile {uuid path} { my API.error EnterFile }

    # Names: ?pattern? --> list(uuid)
    method Names {{pattern *}} { my API.error Names }

    # # ## ### ##### ######## #############
    ## API. Methods for uni- and bi-directional
    ##      synchronization (push, pull, and sync).
    ##      Limited sync possible

    # # ## ### ##### ######## #############
    ## Push (self to other). Synchronous.

    # The initiator, self, delegates the action to the peer for actual
    # control and execution of the operation (methods ihave-*). The
    # method chosen by self encodes which of the get-* methods it
    # prefers. The peer uses this information to optimize the blob
    # transfer, i.e. chooses the API with which it retrieves the
    # blob. The default implementations of the peer/ihave-* methods
    # follow the hint given by the initiator. Derived classes may
    # choose not too. Filtering the uuid list happens only in the
    # peer, as the only side knowing which blobs it is missing.

    # We are self in a push operation.
    method push {destination {uuidlist *}} {
	debug.blob {[debug caller] | }
	# Delegating to the peer for actual control of the operation.
	# The peer will use one of the get-* methods to gain access to
	# the blobs to transfer.
	switch -exact -- [set prefered [my PreferedPut]] {
	    string  { $destination ihave-for-string $uuidlist [self] }
	    path    { $destination ihave-for-file   $uuidlist [self] }
	    chan    { $destination ihave-for-chan   $uuidlist [self] }
	    default { my PREF.error $prefered }
	}
	return
    }

    # We are the peer in a push operation, and have to pull blobs from
    # the source. Three entry-points, one each for the retrieval APIs
    # the source is able to provide and prefers. We ignore the blobs
    # we already have/know.

    method ihave-for-string {uuidlist src} {
	debug.blob {[debug caller] | }
	set uuidlist [$src names {*}$uuidlist]
	foreach uuid $uuidlist {
	    if {[my exists $uuid]} continue
	    my PutVerifyString $uuid $src
	}
	return
    }

    method ihave-for-file {uuidlist src} {
	debug.blob {[debug caller] | }
	set uuidlist [$src names {*}$uuidlist]
	foreach uuid $uuidlist {
	    if {[my exists $uuid]} continue
	    my PutVerifyPath $uuid $src
	}
	return
    }

    method ihave-for-chan {uuidlist src} {
	debug.blob {[debug caller] | }
	set uuidlist [$src names {*}$uuidlist]
	foreach uuid $uuidlist {
	    if {[my exists $uuid]} continue
	    my PutVerifyChan $uuid $src
	}
	return
    }

    method PutVerifyString {uuid src} {
	debug.blob {[debug caller] | }
	set blob [$src get-string $uuid]

	set actual_uuid [my Uuid.blob $blob]
	if {$uuid ne $actual_uuid} {
	    my XFER.error $uuid $actual_uuid
	}

	my EnterString $uuid $blob
	return
    }

    method PutVerifyPath {uuid src} {
	debug.blob {[debug caller] | }
	set path [$src get-file $uuid]

	set actual_uuid [my Uuid.path $path]
	if {$uuid ne $actual_uuid} {
	    file delete -- $path
	    my XFER.error $uuid $actual_uuid
	}

	my EnterFile $uuid $path
	file delete -- $path
	return
    }

    method PutVerifyChan {uuid src} {
	debug.blob {[debug caller] | }
	set channel [$src get-channel $uuid]
	set blob [read $channel]
	close $channel

	set actual_uuid [my Uuid.blob $blob]
	if {$uuid ne $actual_uuid} {
	    my XFER.error $uuid $actual_uuid
	}

	my EnterString $uuid $blob
	return
    }

    # # ## ### ##### ######## #############
    ## Push (self to other). Asynchronous.

    # We are self in a push operation.
    method push-async {donecmd destination {uuidlist *}} {
	debug.blob {[debug caller] | }

	# Delegating to the peer for actual control of the operation.
	# The peer will use one of the get-* methods to gain access to
	# the blobs to transfer.
	switch -exact -- [set prefered [my PreferedPut]] {
	    string  { $destination ihave-async-string $donecmd $uuidlist [self] }
	    path    { $destination ihave-async-file   $donecmd $uuidlist [self] }
	    chan    { $destination ihave-async-chan   $donecmd $uuidlist [self] }
	    default { my PREF.error $prefered }
	}
	return
    }

    # We are the peer in a push operation, and have to pull blobs from
    # the source. Three entry-points, one each per the supported
    # retrieval APIs. We ignore the blobs we already have/know.

    method ihave-async-string {donecmd uuidlist src} {
	debug.blob {[debug caller] | }
	my IHaveAsyncString $donecmd [$src names {*}$uuidlist] $src
	return
    }

    method ihave-async-file {donecmd uuidlist src} {
	debug.blob {[debug caller] | }
	my IHaveAsyncPath $donecmd [$src names {*}$uuidlist] $src
	return
    }

    method ihave-async-chan {donecmd uuidlist src} {
	debug.blob {[debug caller] | }
	my IHaveAsyncChan $donecmd [$src names {*}$uuidlist] $src
	return
    }

    method IHaveAsyncString {donecmd uuidlist src} {
	debug.blob {[debug caller] | }
	while {[llength $uuidlist]} {
	    set uuidlist [lassign $uuidlist uuid]
	    if {[my exists $uuid]} continue
	    my PutVerifyString $uuid $src

	    after 0 [mymethod IHaveAsyncChan $donecmd $uuidlist $src]
	    return
	}
	after 0 $donecmd
	return
    }

    method IHaveAsyncPath {donecmd uuidlist src} {
	debug.blob {[debug caller] | }
	while {[llength $uuidlist]} {
	    set uuidlist [lassign $uuidlist uuid]
	    if {[my exists $uuid]} continue
	    my PutVerifyPath $uuid $src

	    after 0 [mymethod IHaveAsyncPath $donecmd $uuidlist $src]
	    return
	}
	after 0 $donecmd
	return
    }

    method IHaveAsyncChan {donecmd uuidlist src} {
	debug.blob {[debug caller] | }
	while {[llength $uuidlist]} {
	    set uuidlist [lassign $uuidlist uuid]
	    if {[my exists $uuid]} continue
	    my PutVerifyChan $uuid $src

	    after 0 [mymethod IHaveAsyncChan $donecmd $uuidlist $src]
	    return
	}
	after 0 $donecmd
	return
    }

    # # ## ### ##### ######## #############
    ## Pull (self from other). Synchronous.

    # The initiator, self, delegates the action to the peer for actual
    # control and execution of the operation (method iwant). The peer
    # can use the standard APIs (put-string, put-file, put-channel) to
    # enter the blobs with the requested uuids. The peer is free to
    # choose. The standard implementation of the peer (iwant) uses the
    # put-* method indicated as prefered by self, for optimal
    # transfer. The pattern list is filtered in the peer, as the only
    # one knowing what it has. The peer does also filter against the
    # initiator as it has the uuid and thus can do it trivially before
    # a transfer, and thus avoid transfering duplicates. Overall this
    # means that 'pull' may not receive all blobs it requested, as the
    # peer may not have them.

    # We are self in a pull operation.
    method pull {origin {uuidlist *}} {
	debug.blob {[debug caller] | }
	# Delegating to the peer for actual control of the operation.
	# The peer will use one of the 'put-*' methods to enter the
	# blobs to transfer. We indicate through our use of iwant-*
	# which method we prefer.
	if {![llength $uuidlist]} return
	switch -exact -- [set prefered [my PreferedPut]] {
	    string  { $origin iwant-as-string $uuidlist [self] }
	    path    { $origin iwant-as-file   $uuidlist [self] }
	    chan    { $origin iwant-as-chan   $uuidlist [self] }
	    default { my PREF.error $prefered }
	}
	return
    }

    # We are the peer in a pull operation and have to push blobs into
    # the destination. Three entry-points, one each for the placement
    # APIs the source is able to provide and prefers. We ignore the
    # blobs the destination already has/knows.

    method iwant-as-string {uuidlist destination} {
	debug.blob {[debug caller] | }
	set uuidlist [my names {*}$uuidlist]
	foreach uuid $uuidlist {
	    if {[$destination exists $uuid]} continue
	    $destination put-string [my get-string $uuid]
	}
	return
    }

    method iwant-as-file {uuidlist destination} {
	debug.blob {[debug caller] | }
	set uuidlist [my names {*}$uuidlist]
	foreach uuid $uuidlist {
	    if {[$destination exists $uuid]} continue
	    set path [my get-file $uuid]
	    $destination put-file $path
	    file delete -- $path
	}
	return
    }

    method iwant-as-chan {uuidlist destination} {
	debug.blob {[debug caller] | }
	set uuidlist [my names {*}$uuidlist]
	foreach uuid $uuidlist {
	    if {[$destination exists $uuid]} continue
		set channel [my get-channel $uuid]
		$destination put-channel $channel
		close $channel
	}
	return
    }

    # # ## ### ##### ######## #############
    ## Pull (self from other). Asynchronous.

    # We are self in a pull operation.
    method pull-async {donecmd origin {uuidlist *}} {
	debug.blob {[debug caller] | }
	# Delegating to the peer for actual control of the operation.
	# The peer will use one of the put-* methods to enter the
	# blobs to transfer.
	if {![llength $uuidlist]} {
	    after 0 $donecmd
	    return
	}
	switch -exact -- [set prefered [my PreferedPut]] {
	    string  { $origin iwant-async-string $donecmd $uuidlist [self] }
	    path    { $origin iwant-async-file   $donecmd $uuidlist [self] }
	    chan    { $origin iwant-async-chan   $donecmd $uuidlist [self] }
	    default { my PREF.error $prefered }
	}
	return
    }

    # We are the peer in a pull operation and have to push blobs into
    # the destination.
    method iwant-async-string {donecmd uuidlist destination} {
	debug.blob {[debug caller] | }
	set uuidlist [my names {*}$uuidlist]
	my IwantString $donecmd $uuidlist $destination
	return
    }

    method iwant-async-file {donecmd uuidlist destination} {
	debug.blob {[debug caller] | }
	set uuidlist [my names {*}$uuidlist]
	my IwantPath $donecmd $uuidlist $destination
	return
    }

    method iwant-async-chan {donecmd uuidlist destination} {
	debug.blob {[debug caller] | }
	set uuidlist [my names {*}$uuidlist]
	my IwantChan $donecmd $uuidlist $destination
	return
    }

    method IwantString {donecmd uuidlist destination} {
	debug.blob {[debug caller] | }
	while {[llength $uuidlist]} {
	    set uuidlist [lassign $uuidlist uuid]
	    if {[$destination exists $uuid]} continue
	    $destination put-string [my get-string $uuid]

	    after 0 [mymethod IwantString $donecmd $uuidlist $destination]
	    return
	}
	after 0 $donecmd
	return
    }

    method IwantPath {donecmd uuidlist destination} {
	debug.blob {[debug caller] | }
	while {[llength $uuidlist]} {
	    set uuidlist [lassign $uuidlist uuid]
	    if {[$destination exists $uuid]} continue
	    $destination put-file [my get-file $uuid]

	    after 0 [mymethod IwantPath $donecmd $uuidlist $destination]
	    return
	}
	after 0 $donecmd
	return
    }

    method IwantChan {donecmd uuidlist destination} {
	debug.blob {[debug caller] | }
	while {[llength $uuidlist]} {
	    set uuidlist [lassign $uuidlist uuid]
	    if {[$destination exists $uuid]} continue

	    # Optimize: enter from channel?  Not really. Would
	    # just move the common code below into the derived
	    # classes.

	    set channel [my get-channel $uuid]
	    $destination put-channel $channel
	    close $channel

	    after 0 [mymethod IwantChan $donecmd $uuidlist $destination]
	    return
	}
	after 0 $donecmd
	return
    }

    # # ## ### ##### ######## #############
    # Sync (self push/pull to/from other). Synchronous.

    # The initiator, self, delegates the action to the peer for actual
    # control and execution of the operation (methods iexchange-*).
    # The method chosen by self encodes which of the get-* and put-*
    # methods it prefers. The peer uses this information to optimize
    # the blob transfer, i.e. chooses the API with which it retrieves
    # the blob. The default implementations of the peer/ihave-* follow
    # the hint given by the initiator. Filtering the uuid list happens
    # only in the peer, as the only side knowing which blobs it is
    # missing.

    method sync {peer {uuidlist *}} {
	debug.blob {[debug caller] | }
	# Delegating to the peer for actual control of the operation.
	# The peer will use one of the get-* and put-* methods to gain
	# access to the blobs to transfer.
	switch -exact -- [set prefered [my PreferedPut]] {
	    string  { $peer iexchange-for-string $uuidlist [self] }
	    path    { $peer iexchange-for-file   $uuidlist [self] }
	    chan    { $peer iexchange-for-chan   $uuidlist [self] }
	    default { my PREF.error $prefered }
	}
	return
    }

    # We are the peer in a sync operation, and have to push and pull
    # blobs to and from the source. Two entry-points, depending on the
    # retrieval API the source is able to provide. We ignore the blobs
    # we already have/know. Internally we call on the existing APIs
    # for pushing and pulling.

    method iexchange-for-string {uuidlist peer} {
	debug.blob {[debug caller] | }
	my ihave-for-string $uuidlist $peer
	my iwant-as-string  $uuidlist $peer
	return
    }

    method iexchange-for-file {uuidlist peer} {
	debug.blob {[debug caller] | }
	my ihave-for-file $uuidlist $peer
	my iwant-as-file  $uuidlist $peer
	return
    }

    method iexchange-for-chan {uuidlist peer} {
	debug.blob {[debug caller] | }
	my ihave-for-chan $uuidlist $peer
	my iwant-as-chan  $uuidlist $peer
	return
    }

    # # ## ### ##### ######## #############
    ## Sync. Asynchronous.

    method sync-async {donecmd peer {uuidlist *}} {
	debug.blob {[debug caller] | }
	# Delegating to the peer for actual control of the operation.
	# The peer will use one of the get-* and put-* methods to gain
	# access to the blobs to transfer.
	switch -exact -- [set prefered [my PreferedPut]] {
	    string  { $peer iexchange-async-string $donecmd $uuidlist [self] }
	    path    { $peer iexchange-async-file   $donecmd $uuidlist [self] }
	    chan    { $peer iexchange-async-chan   $donecmd $uuidlist [self] }
	    default { my PREF.error $prefered }
	}
	return
    }

    method iexchange-async-string {donecmd uuidlist peer} {
	debug.blob {[debug caller] | }
	# donecmd - generate a merger which triggers done only when
	# both parts are completed.

	set donecmd [mymethod IExchDone [my IExchState] $donecmd]

	my ihave-async-string $donecmd $uuidlist $peer
	my iwant-async-string $donecmd $uuidlist $peer
	return
    }

    method iexchange-async-file {donecmd uuidlist peer} {
	debug.blob {[debug caller] | }
	# donecmd - generate a merger which triggers done only when
	# both parts are completed.

	set donecmd [mymethod IExchDone [my IExchState] $donecmd]

	my ihave-async-file $donecmd $uuidlist $peer
	my iwant-async-file $donecmd $uuidlist $peer
	return
    }

    method iexchange-async-chan {donecmd uuidlist peer} {
	debug.blob {[debug caller] | }
	# donecmd - generate a merger which triggers done only when
	# both parts are completed.

	set donecmd [mymethod IExchDone [my IExchState] $donecmd]

	my ihave-async-chan $donecmd $uuidlist $peer
	my iwant-async-chan $donecmd $uuidlist $peer
	return
    }

    method IExchState {} {
	debug.blob {[debug caller] | }
	set n [incr myexchcounter]
	variable merge$n 2
	return $n
    }

    method IExchDone {id donecmd} {
	debug.blob {[debug caller] | }
	variable merge$id
	upvar  0 merge$id mergecount

	incr mergecount -1
	if {$mergecount > 0} return
	unset merge$id

	after 0 $donecmd
	return
    }

    # # ## ### ##### ######## #############
    ## Internal helpers

    method Uuid.blob {blob} {
	sha1::sha1 -hex -- $blob
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

    method Validate {uuid} {
	if {[my exists $uuid]} return
	my Error "Expected uuid, got \"$uuid\"" BAD UUID $uuid
    }

    method API.error {api} {
	my Error "Unimplemented API $api" API MISSING $api
    }

    method XFER.error {expected actual} {
	my Error "Transfer uuid mismatch, expected $expected, got $actual" \
	    XFER MISMATCH $expected $actual
    }

    method PREF.error {bad} {
	my Error "Expected one of string, chan, or path, got \"$bad\"" \
	    BAD PREFERENCE $bad
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob 0
return
