## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc store-class {} { lindex [split [test-class] /] 0 }

proc new-store {{suffix {}}} {
    sqlite3              test-database$suffix :memory:
    blob::sqlite create  test-backend$suffix  ::test-database$suffix blocks
    [store-class] create test-store$suffix    512 ::test-backend$suffix ::test-database$suffix blobs
    return
}

proc release-store {{suffix {}}} {
    catch { test-store$suffix    destroy }
    catch { test-backend$suffix  destroy }
    catch { test-database$suffix close   }
    return
}

# # ## ### ##### ######## ############# #####################
return
