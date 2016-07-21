## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-store {{suffix {}}} {
    file mkdir _blobfs_$suffix
    [test-class] create test-store$suffix _blobfs_$suffix
    return
}

proc release-store {{suffix {}}} {
    test-store$suffix destroy
    file delete -force _blobfs_$suffix
    return
}

# # ## ### ##### ######## ############# #####################
return
