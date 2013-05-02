## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-store {} {
    sqlite3 mydb :memory:
    return [blob::sqlite create myblob ::mydb blobs]
}

proc release-store {} {
    catch { myblob destroy }
    catch { mydb     close }
    return
}

# # ## ### ##### ######## ############# #####################
return
