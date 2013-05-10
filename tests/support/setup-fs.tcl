## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-store {} {
    file mkdir _blobfs_
    [test-class] create test-store _blobfs_
    return
}

proc release-store {} {
    test-store destroy
    file delete -force _blobfs_
    return
}

# # ## ### ##### ######## ############# #####################
return
