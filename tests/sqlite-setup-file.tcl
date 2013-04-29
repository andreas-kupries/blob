## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-store {} {
    global store_path
    set    store_path [file normalize _blob_[pid]_]
    sqlite3 mydb $store_path
    return [blob::sqlite create myblob ::mydb blobs]
}

proc release-store {} {
    global store_path
    catch { myblob destroy }
    catch { mydb     close }
    file delete $store_path
    unset store_path
    return
}

# # ## ### ##### ######## ############# #####################
return
