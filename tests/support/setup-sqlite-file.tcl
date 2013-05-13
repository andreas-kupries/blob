## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc store-class {} { lindex [split [test-class] /] 0 }

proc new-store {{suffix {}}} {
    sqlite3              test-database$suffix [file normalize _blob_[pid]_$suffix]
    [store-class] create test-store$suffix    ::test-database$suffix blobs
    return
}

proc release-store {{suffix {}}} {
    catch { test-store$suffix    destroy }
    catch { test-database$suffix close   }
    file delete [file normalize _blob_[pid]_$suffix]
    return
}

# # ## ### ##### ######## ############# #####################
return
