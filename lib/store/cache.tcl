# -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## In-memory blob cache to front other blob storage instances.
##
## Attributes:
## - Write-through of blobs
## - Loads blobs only on retrieval
##   - Limited number of blobs kept in memory
## - Separate cache for blob existence information
##   - Limited as well, although at a higher level.

# @@ Meta Begin
# Package blob::cache 1
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
package require blob::option
package require tcl::chan::string ; # tcllib
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define blob/cache
debug level  blob/cache
#debug prefix blob/cache {[debug caller] | }
debug prefix blob/cache {} ;# No prefix, arguments can be large

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create blob::cache {
    superclass blob

    # # ## ### ##### ######## #############
    ## State

    variable myhas mydata myhaslog mydatalog
    # myhas:  dict (uuid -> boolean)
    # mydata: dict (uuid -> blob)
    # my*log:  list(uuid) - LRU at end

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {backend args} {
	debug.blob/cache {[debug caller] | }

	# Make the backend available as a local command, under a fixed
	# name. No need for an instance variable and resolution.
	interp alias {} [self namespace]::BACKEND {} $backend

	blob::option create [self namespace]::OPTION {
	    {-blob-limit 100}
	    {-uuid-limit 10000}
	}

	my clear
	next
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    method PreferedPut {} { return string }

    # put-string :- enter-string: uuid, blob --> ()
    method enter-string {uuid blob} {
	debug.blob/cache {}

	# Write-through
	BACKEND enter-string $uuid $blob

	# And maintain uuid cache
	my Push myhas $uuid 1 [OPTION cget -uuid-limit]
	return
    }

    # put-file:- enter-file: path --> ()
    method enter-file {uuid path} {
	debug.blob/cache {[debug caller] | }

	# Write-through
	BACKEND enter-file $uuid $path

	# And maintain uuid cache
	my Push myhas $uuid 1 [OPTION cget -uuid-limit]
	return
    }

    # get-string: uuid --> blob
    method get-string {uuid} {
	debug.blob/cache {[debug caller] | }
	my Validate $uuid
	set limit [OPTION cget -blob-limit]
	if {($limit ne {}) && !$limit} {
	    return [BACKEND get-string $uuid]
	}
	return [my EnsureData $uuid $limit]
    }

    # get-channel: uuid --> channel
    method get-channel {uuid} {
	debug.blob/cache {}
	my Validate $uuid
	set limit [OPTION cget -blob-limit]
	if {($limit ne {}) && !$limit} {
	    return [BACKEND get-channel $uuid
	}
	return [tcl::chan::string [my EnsureData $uuid $limit]]
    }

    # names () -> list(uuid)
    method Names {{pattern *}} {
	debug.blob/cache {[debug caller] | }
	return [BACKEND names $pattern]
    }

    # exists: string -> boolean
    method exists {uuid} {
	debug.blob/cache {[debug caller] | }
	set limit [OPTION cget -uuid-limit]
	if {($limit ne {}) && !$limit} {
	    return [BACKEND exists $uuid]
	}
	return [my EnsureExists $uuid $limit]
    }

    # size () -> integer
    method size {} {
	debug.blob/cache {[debug caller] | }
	return [BACKEND size]
    }

    # clear () -> ()
    method clear {} {
	debug.blob/cache {[debug caller] | }
	set myhas     {}
	set myhaslog  {}
	set mydata    {}
	set mydatalog {}
	BACKEND clear
	return
    }

    # delete: uuid -> ()
    method remove {uuid} {
	debug.blob/cache {[debug caller] | }
	BACKEND remove $uuid
	my DropData $uuid
	my Push myhas $uuid 0 [OPTION cget -uuid-limit]
	return
    }

    # # ## ### ##### ######## #############
    ## Cache-specific manipulation and introspection methods

    forward cget      OPTION cget
    forward configure OPTION configure

    method blobs {} {
	debug.blob/cache {[debug caller] | ==> [dict size $mydata]}
	return [dict size $mydata]
    }

    method uuids {} {
	debug.blob/cache {[debug caller] | ==> [dict size $myhas]}
	return [dict size $myhas]
    }

    method blobs-loaded {} {
	debug.blob/cache {[debug caller] | ==> [dict keys $mydata]}
	return [dict keys $mydata]
    }

    method uuids-loaded {} {
	debug.blob/cache {[debug caller] | ==> ([dict keys 4myhas])}
	return [dict keys $myhas]
    }

    method blobs-lru {} {
	debug.blob/cache {[debug caller] | ==> ($mydatalog)}
	return $mydatalog
    }

    method uuids-lru {} {
	debug.blob/cache {[debug caller] | ==> ($myhaslog)}
	return $myhaslog
    }

    # # ## ### ##### ######## #############

    method Push {var uuid value limit} {
	debug.blob/cache {[debug caller] | }

	# Bail out immediately if the relevant cache is disabled.
	if {$limit == 0} return

	upvar 1 $var store ${var}log log

	set known [dict exists $store $uuid]
	dict set store $uuid $value

	# Bail out early for an unlimited cache.
	# We must not maintain the LRU log.
	if {$limit eq {}} return

	# Limited cache, maintain an LRU log, may drop value from the
	# store.

	# TODO :: critcl -- LRU data structure in C, for fast
	# operation.

	if {!$known} {
	    # Data not stored, extend cache.
	    if {[llength $log] >= $limit} {
		# Cache limit reached. Drop longest unused entry.
		dict unset store [lindex $log 0]
		set log [lrange $log 1 end]
	    }
	    # Under the limit so far, or now, simply add
	    lappend log $uuid
	} else {
	    # uuid is known. Pull to front as last used.
	    set pos [lsearch -exact $log $uuid]
	    set log [linsert [lreplace $log $pos $pos] end [lindex $log $pos]]
	}
	return
    }

    method Ref {var uuid} {
	debug.blob/cache {[debug caller] | }
	upvar 1 $var store ${var}log log

	# Pull uuid to front as last used.
	set pos [lsearch -exact $log $uuid]
	set log [linsert [lreplace $log $pos $pos] end [lindex $log $pos]]
	return
    }

    method EnsureData {uuid limit} {
	debug.blob/cache {[debug caller] | }
	if {![dict exists $mydata $uuid]} {
	    my Push mydata $uuid \
		[BACKEND get-string $uuid] \
		$limit
	} else {
	    my Ref mydata $uuid
	}
	return [dict get $mydata $uuid]
    }

    method EnsureExists {uuid limit} {
	debug.blob/cache {[debug caller] | }
	if {![dict exists $myhas $uuid]} {
	    my Push myhas $uuid \
		[BACKEND exists $uuid] \
		$limit
	} else {
	    my Ref myhas $uuid
	}
	return [dict get $myhas $uuid]
    }

    method DropData {uuid} {
	debug.blob/cache {[debug caller] | }

	# Quick bailout if the blob is not in the cache.
	if {![dict exists $mydata $uuid]} return

	# Drop blob from cache, and maintain the LRU log.
	dict unset mydata $uuid
	set pos       [lsearch -exact $mydatalog $uuid]
	set mydatalog [lreplace $mydatalog $pos $pos]
	return
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide blob::cache 0
return
