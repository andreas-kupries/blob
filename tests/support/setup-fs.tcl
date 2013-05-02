## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-store {} {
    file mkdir _blobfs_
    return [blob::fs create myblob _blobfs_]
}

proc release-store {} {
    myblob destroy
    file delete -force _blobfs_
    return
}

# # ## ### ##### ######## ############# #####################
return
