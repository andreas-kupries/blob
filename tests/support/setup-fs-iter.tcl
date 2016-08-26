## -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-iter {{suffix {}}} {
    file mkdir                            _blobfsi_[pid]_$suffix
    [test-class] create test-iter$suffix  _blobfsi_[pid]_$suffix
    return
}

proc release-iter {{suffix {}}} {
    test-iter$suffix destroy
    file delete -force _blobfsi_[pid]_$suffix
    return
}

# FS::ITER has an additional 'base' method. We re-use the generic
# definition and simply edit the list it returned.
proc iter-methods {} [list return [linsert [iter-methods] 4 base]]

# pre-add-entry - inherited no-op - setup-iter.tcl

# # ## ### ##### ######## ############# #####################
return
