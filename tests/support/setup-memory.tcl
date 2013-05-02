## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-store {} {
    return [blob::memory create myblob]
}

proc release-store {} {
    myblob destroy
    return
}

# # ## ### ##### ######## ############# #####################
return
