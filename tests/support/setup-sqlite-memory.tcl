## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc store-class {} { lindex [split [test-class] /] 0 }

proc new-store {} {
    sqlite3              test-database :memory:
    [store-class] create test-store    ::test-database blobs
    return
}

proc release-store {} {
    catch { test-store    destroy }
    catch { test-database close   }
    return
}

# # ## ### ##### ######## ############# #####################
return
