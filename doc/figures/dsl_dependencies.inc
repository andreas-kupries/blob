# -*- tcl -*-
# # ## ### ##### ######## #############
## DSL parameters, defaults.

proc default {var value} {
    upvar 1 $var v
    if {[info exists v]} return
    set v $value
}

default grid [3 mm]
default bw   8
default bh   4
default ll   2
#default textfont {Helvetica 10}

# # ## ### ##### ######## #############
## Derived values

set boxwidth     [expr {$bw   * $grid}]
set boxheight    [expr {$bh   * $grid}]
set movelength   [expr {$ll   * $grid}]
set arcradius    [expr {$ll/2 * $grid}]

proc grid {n} {
    variable grid
    expr {$n * $grid}
}

# # ## ### ##### ######## #############
## Macros for dependency arrows and navigation.

proc --- {{n 1}} {
    variable movelength
    line [direction] [expr {$n * $movelength}]
}
proc ---> {{n 1}} {
    variable movelength
    arrow [direction] [expr {$n * $movelength}]
}
proc l {} { arc cw }
proc r {} { arc }
proc d {} { if {[direction] eq "west"} { arc } else { arc cw } }

# # ## ### ##### ######## #############
return
