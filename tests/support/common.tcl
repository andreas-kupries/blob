## -*- tcl -*-
## (c) 2013 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc already {cmd} {
    return "can't create object \"$cmd\": command already exists with that name"
}

proc badmethod {m real} {
    set real [string map {{, or} { or}} [linsert [join $real {, }] end-1 or]]
    return "unknown method \"$m\": must be $real"
}

proc methods {} {
    return {add channel clear delete destroy exists iexchange-async-chan iexchange-async-path iexchange-for-chan iexchange-for-path ihave-async-chan ihave-async-path ihave-for-chan ihave-for-path iwant iwant-async names pull pull-async push push-async put retrieve size sync sync-async}
}

proc setup-wall   {} { set   ::wall 0 }
proc wait-wall    {} { vwait ::wall   }
proc pass-wall    {} { set   ::wall 1 }
proc release-wall {} { unset ::wall   }

# # ## ### ##### ######## ############# #####################
return
