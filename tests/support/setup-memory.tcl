## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-store {} {
    [test-class] create test-store
    return
}

proc release-store {} {
    test-store destroy
    return
}

# # ## ### ##### ######## ############# #####################
return
