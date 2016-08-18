## -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc iter-class {} { lindex [split [test-class] /] 0 }

# Redefine store class, drop reference to iteration
proc store-class {} { string map {::iter {}} [iter-class] }

proc new-iter {{suffix {}}} {
    new-store $suffix             ;# ==> ::test-database$suffix blobs
    [iter-class] create test-iter$suffix ::test-database$suffix blobs blobiter
    return
}

proc release-iter {{suffix {}}} {
    test-iter$suffix destroy
    release-store $suffix
    return
}

proc pre-add-entry {uuid key {suffix {}}} {
    # Add a fake entry to the blob table the iterator can then find
    # when joining on the uuid. No actual data.
    ::test-database$suffix eval {
	INSERT INTO blobs VALUES (NULL,:uuid,NULL)
    }
    return
}

# # ## ### ##### ######## ############# #####################
return
