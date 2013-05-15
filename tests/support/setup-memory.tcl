## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-store {{suffix {}}} {
    [test-class] create test-store$suffix
    return
}

proc release-store {{suffix {}}} {
    test-store$suffix destroy
    return
}

# # ## ### ##### ######## ############# #####################
return
