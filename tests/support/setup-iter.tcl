## -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc pre-add-entry {args} {}

proc iter-methods {} {
    return {--> := add at clear data data! destroy direction direction! exists get location next previous remove reset reverse size to}
}

proc iter-data {} {
    # 20 entries, enough for sensible testing of iterator navigation
    # and paging
    return {
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
    }
}

proc iter-fill {{suffix {}}} {
    test-iter$suffix clear
    foreach {key uuid} [iter-data] {
	pre-add-entry $uuid $key $suffix
	test-iter$suffix add $uuid $key
    }
    return
}

proc sort-iter {data} {
    return [lsort -index 1 [lsort -index 0 $data]]
}

# # ## ### ##### ######## ############# #####################
return
