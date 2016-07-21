
[def [file build.tcl]]
The main file of the [syscmd kettle]-based build-system.

[def [file doc/]]
Main directory for all documentation.

[para] Based on the [package doctools] package and tools provided by
[package Tcllib].

[def [file doc/figures/]]
Main directory for all diagrams and figures used by the documentation.

[para] Based on the [package diagram] package and tools provided by
[package Tklib].


[def [file embedded/]]
Compiled documentation (manpages and HTML).

Part of the repository for

[list_begin enumerated]
[enum] easy access from the repository's web interface
([uri http://fossil-scm.org/index.html/doc/tip/www/embeddeddoc.wiki {embedded documentation}]),
and
[enum] quicker installation (no need to compile during the
installation process itself).
[list_end]


[def [file tests/]]
Main directory for the test-suite.

[para] Based on the [package tcltest] package distributed with the Tcl
core.
