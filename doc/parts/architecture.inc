
[para] All packages to one of two layers,
as shown below:

[para][image architecture]

[para] Note that:

[list_begin itemized]

[item] Packages marked with a dashed border are private.

[item] Packages marked with an unbroken blue border are fully public.

[item] The topmost layer contains the various public storage backends.

[item] The other, supporting, layer contains only a single package,
[package [vset PROJECT]], the base class for all others.
[list_end]

[para] The dependencies between the packages are very
straight-forward:

[para][image pkg_dependencies]
