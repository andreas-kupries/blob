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
    return {add channel clear delete destroy exists ihave-for-chan ihave-for-path iwant names pull push put retrieve size}
}

# # ## ### ##### ######## ############# #####################
return
