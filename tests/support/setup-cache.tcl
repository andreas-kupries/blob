## -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-store {{suffix {}}} {
    [test-class] create test-store$suffix \
	[blob::memory create test-memory-store$suffix]
    return
}

proc release-store {{suffix {}}} {
    test-store$suffix        destroy
    test-memory-store$suffix destroy
    return
}

# Cache has additional introspection methods. We re-use the generic
# definition and simply edit the list it returned.

proc methods {} [list return [lsort [linsert [methods] 0 \
					 blobs blobs-loaded blobs-lru \
					 uuids uuids-loaded uuids-lru \
					 cget configure \
					]]]

# # ## ### ##### ######## ############# #####################
return
