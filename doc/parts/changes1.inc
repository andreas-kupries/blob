[subsection {Changes for version 1}]

This is the first release of [vset PROJECT].
The changes therefore describe the initial features of the system.

[para] In detail:

[list_begin enumerated]
[comment {- - -- --- ----- -------- ------------- ---------------------}]

[enum] [vset PROJECT] requires Tcl 8.5 or higher.
       Tcl 8.4 or less is not supported.

[enum] The project provides a base class declaring the API of blob
       storage classes, and three implementations of that API.

[enum] The provided implementations store content in an sqlite
       database, in the filesystem, or in memory.

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[list_end]
