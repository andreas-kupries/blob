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

# Override common definition. One additional method (path).
proc methods {} {
    return {add channel clear delete destroy exists iexchange-for-chan iexchange-for-path ihave-async-chan ihave-async-path ihave-for-chan ihave-for-path iwant iwant-async names path pull pull-async push push-async put retrieve size sync}
}

# # ## ### ##### ######## ############# #####################
return
