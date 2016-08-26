## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-store {{suffix {}}} {
    file mkdir                            _blobfs_[pid]_$suffix
    [test-class] create test-store$suffix _blobfs_[pid]_$suffix
    return
}

proc release-store {{suffix {}}} {
    test-store$suffix destroy
    file delete -force _blobfs_[pid]_$suffix
    return
}

# FS has an additional 'base' method. We re-use the generic definition
# and simply edit the list it returned.
proc methods {} [list return [linsert [methods] 0 base]]

# # ## ### ##### ######## ############# #####################
return
