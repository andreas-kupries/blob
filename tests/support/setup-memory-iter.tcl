## -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-iter {{suffix {}}} {
    [test-class] create test-iter$suffix
    return
}

proc release-iter {{suffix {}}} {
    test-iter$suffix destroy
    return
}

# pre-add-entry - inherited no-op - setup-iter.tcl

# # ## ### ##### ######## ############# #####################
return
