## -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-store {{suffix {}}} {
    [test-class] create test-store$suffix
    return
}

proc release-store {{suffix {}}} {
    test-store$suffix destroy
    return
}

# statistics has additional methods: min, max, bytes-stored,
# bytes-entered, average. We re-use the generic definition and simply
# edit the list it returned.
proc methods {} [list return [lsort [linsert [methods] 0 \
					 min max average \
					 bytes-stored \
					 bytes-entered]]]

proc blob-result {x} {
    dict get {
	02aa629c8b16cd17a44f3a0efec2feed43937642  1
	06576556d1ad802f247cad11ae748be47b70cd9c  1
    } $x
}

proc serialize {} { return 0 }

# # ## ### ##### ######## ############# #####################
return
