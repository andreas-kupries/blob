## -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc iter-class {} { lindex [split [test-class] /] 0 }

# Redefine store class, drop reference to iteration
proc store-class {} { string map {::iter {}} [iter-class] }

proc new-iter {{suffix {}}} {
    new-store $suffix             ;# ==> ::test-database$suffix blobs
    [iter-class] create test-iter$suffix ::test-database$suffix \
	-blob-table {} \
	-iter-table blobiter
    return
}

proc release-iter {{suffix {}}} {
    test-iter$suffix destroy
    release-store $suffix
    return
}

# # ## ### ##### ######## ############# #####################
return
