## -*- tcl -*-
## (c) 2013-2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc already {cmd} {
    return "can't create object \"$cmd\": command already exists with that name"
}

proc badmethod {m real} {
    set real [string map {{, or} { or}} [linsert [join $real {, }] end-1 or]]
    return "unknown method \"$m\": must be $real"
}

proc methods {} {
    return {clear delete destroy exists get-channel get-file get-string iexchange-async-chan iexchange-async-file iexchange-async-string iexchange-for-chan iexchange-for-file iexchange-for-string ihave-async-chan ihave-async-file ihave-async-string ihave-for-chan ihave-for-file ihave-for-string iwant-as-chan iwant-as-file iwant-as-string iwant-async-chan iwant-async-file iwant-async-string names new pull pull-async push push-async put-channel put-file put-string remove size store-to-file sync sync-async}
}

proc iter-methods {} {
    return {--> := add at clear data data! destroy direction direction! exists location next previous remove reset reverse size to}
}

proc iter-fill {{suffix {}}} {
    # 20 entries, enough for sensible testing of iterator navigation and paging
    test-iter$suffix clear
    foreach {key uuid} {
	baron    0D
	baroness 05
	count    0B
	countess 04
	dame     01
	duchess  06
	duke     0C
	emperor  0F
	empress  07
	graf     0A
	heir     12
	heiress  13
	herr     09
	king     0E
	lady     00
	lord     08
	prince   10
	princess 11
	queen    03
	woman    02
    } {
	pre-add-entry $uuid $key $suffix
	test-iter$suffix add $uuid $key
    }
    return
}

proc setup-wall   {} { set   ::wall 0 }
proc wait-wall    {} { vwait ::wall   }
proc pass-wall    {} { set   ::wall 1 }
proc release-wall {} { unset ::wall   }

proc sort-iter {data} {
    return [lsort -index 1 [lsort -index 0 $data]]
}

# # ## ### ##### ######## ############# #####################
return
