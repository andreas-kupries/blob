
[subsection Tcllib]

The framework requires six packages found in Tcllib.
These are

[list_begin enumerated]
[enum] [package debug]
[enum] [package debug::caller]
[enum] [package fileutil]
[enum] [package oo::util]
[enum] [package sha1]
[enum] [package try]
[list_end]

[para] Out of the many possibilites for getting Tcllib (OS vendor,
os-independent vendor, building from sources) use whatever you are
comfortable with.

[para] For myself, I am most comfortable with using
[uri http://www.activestate.com ActiveState's]
ActiveTcl distribution and TEApot.

[para] See the previous section ([sectref Tcl]) for disclosure and
information on how to get it.

[para] Assuming that ActiveTcl got installed running the commands

[example {
    teacup install debug
    teacup install debug::caller
    teacup install fileutil
    teacup install oo::util
    teacup install sha1
    teacup install try
}]

will install them for your platform, if you have not done the more
inclusive

[example {
    teacup update
}]

to get everything and the kitchensink.

[para] For those wishing to build and install Tcllib on their own, the
relevant sources can be found at [uri http://core.tcl.tk/tcllib]
together with the necessary instructions on how to build it.

[para] If there are problems with building, installing, or using
Tcllib and its packages please file a bug against Tcllib, or the
vendor of your distribution, and not [package [vset PROJECT]].
