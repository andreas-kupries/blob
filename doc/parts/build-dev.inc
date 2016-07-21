
Our build-system is based on [syscmd kettle], as already explained in
the [term [vset TITLE_INSTALL]]. Beyond the targets useful for
installation it also provides targets aiding developers and
maintainers. These are:

[list_begin definitions]

[def {Validation of the documentation}]

[example_begin]
% /path/to/[vset PROJECT]/build.tcl validate-doc
[example_end]


[def {Regeneration of the embedded documentation}]

[example_begin]
% /path/to/[vset PROJECT]/build.tcl doc
[example_end]

[def {Regeneration of the figures for the documentation}]

[example_begin]
% /path/to/[vset PROJECT]/build.tcl figures
[example_end]


[def {Execution of the test-suite}]

The most basic execution of the test-suite is done with

[example_begin]
% /path/to/[vset PROJECT]/build.tcl test
[example_end]

[para] When the test-suite reports issues with the framework use of
the more extended form below is indicated, with a [const <stem>] of
your choice. This will generate a number of files whose name starts
with the prefix [file <stem>.]. These will contain extended test logs,
details about errors and failures, etc.

[example_begin]
% /path/to/[vset PROJECT]/build.tcl test --log <stem>
[example_end]


[list_end]
