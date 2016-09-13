
[section {Standard API}]

As a derived class of [package [vset PROJECT]] instances of this class
provide the following methods to their users:

[list_begin definitions]
	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method put-string] [arg blob]]

		This method adds the string [arg blob] to the instance
		and returns the blob's uuid as the result of the
		method. Adding the same string multiple times actually
		adds it only on the first call, and all invokations
		return the same uuid.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method put-file] [arg path]]

		This method adds the (binary) string found in the file
		at the specified [arg path] to the instance and
		returns the blob's uuid as the result of the
		method. Adding the same content multiple times
		actually adds it only on the first call, and all
		invokations return the same uuid.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method put-channel] [arg chan]]

		This method adds the (binary) string found in the
		channel [arg chan] to the instance and returns the
		blob's uuid as the result of the method. Adding the
		same content multiple times actually adds it only on
		the first call, and all invokations return the same
		uuid.

	[para]	The content is read from [arg chan] once, starting at
		the current location. After the call the channel is
		positioned at EOF. Note that the caller has to close
		the channel.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method new]]

		This method returns a boolean value indicating if the
		last call to one of the [method put-*] methods
		actually added a new blob ([const true]), or not
		([const false]).

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method get-string] [arg uuid]]

		This method locates the contents of blob [arg uuid]
		and returns them as the result of the method.

		An error is thrown if [arg uuid] is not known to the
		instance.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method get-channel] [arg uuid]]

		This method locates the contents of blob [arg uuid]
		and returns a channel containing it as the result of
		the method.

		An error is thrown if [arg uuid] is not known to the
		instance.

	[para]	The returned channel is read-only, binary, and
		positioned at the beginning of the blob content. No
		assurances are made about the ability to seek the
		channel. It is the responsibility of the caller to
		close the channel after use.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method get-file] [arg uuid]]

		This method locates the contents of blob [arg uuid]
		and returns the path of a file containing it as the
		result of the method.

		An error is thrown if [arg uuid] is not known to the
		instance.

	[para]	The returned file should be considered transient. It
		is owned by the caller and can be moved, modified, and
		deleted at will. It is the responsibility of the
		caller to delete the file after use.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method store-to-file] [arg uuid] [arg path]]

		This method locates the contents of blob [arg uuid]
		and stores them into the file with the specified
		[arg path]. Any previous content of the file is
		overwritten by this operation. The result of the
		method is the empty string.

		An error is thrown if [arg uuid] is not known to the
		instance.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method remove] [arg uuid]]

		This method locates the blob [arg uuid] and removes it
		from the instance. The result of the method is the
		empty string.

		An error is thrown if [arg uuid] is not known to the
		instance.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method clear]]

		This method removes all blobs from the instance. After
		the call the instance is empty. The result of the
		method is the empty string.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method size]]

		This method determines the number of blobs found in
		the instance and returns that number as the result of
		the method.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method names] [opt [arg pattern]...]]

		This method determines the uuids of all blobs found in
		the store which match one or more of the specified
		glob patterns, and returns a list containing them.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method exists] [arg uuid]]

		This method returns a boolean value indicating if the
		blob [arg uuid] is known to the instance
		([const true]), or not ([const false]).

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method push] [arg to] [opt [arg uuids]]]
	[call [cmd <instance>] [method push-async] [arg donecmd] [arg to] [opt [arg uuids]]]

		This method copies the blobs specified by the list of
		[arg uuids] from the instance to the specified peer
		[arg to]. This has to be an object exporting the same
		API as documented for [package [vset PROJECT]].

		The result of the method is the empty string.

	[para]	If no set of uuids is specified the operation will
		push all blobs found in the instance, as if
		"[arg uuids] == [const *] had been specified".

	[para]	Note that the elements of [arg uuids] are interpreted
		as glob patterns.

	[para]	In the [method push-async] form the execution is done
		through the event-loop, invoking the command prefix
		[arg donecmd] when the operation completes, with no
		additional arguments.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method pull] [arg from] [opt [arg uuids]]]
	[call [cmd <instance>] [method pull-async] [arg donecmd] [arg from] [opt [arg uuids]]]

		This method copies the blobs specified by the list of
		[arg uuids] from the specified peer [arg from] to the
		instance. The peer has to be an object exporting the
		same API as documented for [package [vset PROJECT]].

		The result of the method is the empty string.

	[para]	If no set of uuids is specified the operation will
		pull all blobs found in the peer, as if
		"[arg uuids] == [const *] had been specified".

	[para]	Note that the elements of [arg uuids] are interpreted
		as glob patterns.

	[para]	In the [method pull-async] form the execution is done
		through the event-loop, invoking the command prefix
		[arg donecmd] when the operation completes, with no
		additional arguments.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method sync] [arg with] [opt [arg uuids]]]
	[call [cmd <instance>] [method sync-async] [arg donecmd] [arg with] [opt [arg uuids]]]

		This method exchanges the blobs specified by the list
		of [arg uuids] with the specified peer [arg with],
		copying from and to the instance, as needed. The peer
		has to be an object exporting the same API as
		documented for [package [vset PROJECT]].

		The result of the method is the empty string.

	[para]	If no set of uuids is specified the operation will
		exchange all blobs found in the instance and the peer,
		as if "[arg uuids] == [const *] had been specified".

	[para]	Note that the elements of [arg uuids] are interpreted
		as glob patterns.

	[para]	In the [method sync-async] form the execution is done
		through the event-loop, invoking the command prefix
		[arg donecmd] when the operation completes, with no
		additional arguments.
[list_end]
