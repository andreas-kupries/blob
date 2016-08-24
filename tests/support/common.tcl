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

proc setup-wall   {} { set   ::wall 0 }
proc wait-wall    {} { vwait ::wall   }
proc pass-wall    {} { set   ::wall 1 }
proc release-wall {} { unset ::wall   }

# # ## ### ##### ######## ############# #####################
return
