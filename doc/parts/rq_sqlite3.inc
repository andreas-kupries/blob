
[subsection Sqlite]

Sqlite is required by the [package [vset PROJECT]::sqlite] package.

[para] Out of the many possibilites for getting sqlite and its Tcl
bindings (OS vendor, os-independent vendor, building from sources) use
whatever you are comfortable with.

[para] For myself, I am most comfortable with using
[uri https://www.activestate.com ActiveState's]
ActiveTcl distribution and TEApot.

[para] See the previous section ([sectref Tcl]) for disclosure and
information on how to get it.

[para] Assuming that ActiveTcl got installed running the command

[example {
    teacup install sqlite3
}]

will install the package for your platform, if you have not done the
more inclusive

[example {
    teacup update
}]

to get everything and the kitchensink.

[para] For those wishing to build and install sqlite and its Tcl
bindings on their own, the relevant sources can be found at

[uri https://sqlite.org] together with the necessary instructions on
how to build it.

[para] If there are problems with building, installing, or using
Sqlite please file a bug against Sqlite, or the vendor of your
distribution, and not [package [vset PROJECT]].
