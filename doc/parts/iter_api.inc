
[section {Standard API}]

As a derived class of [package [vset PROJECT]::iter] instances of this
class provide the following methods to their users:

[list_begin definitions]
	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method add] [arg uuid] [arg value]]

		This method associates the [arg property_value] with
		the blob specified by its [arg uuid]. The result of
		the method is the empty string. An error is thrown if
		the uuid is already associated with a value. This
		means that each uuid can only be associated with a
		single value, although each value can have multiple
		uuids associated with it.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method remove] [arg uuid]]

		This method removes the specified [arg uuid]s from the
		iterator. The result of the method is the empty
		string. Unknown uuids are ignored. If a removed uuid
		is the [term current] uuid the iterator is stepped
		forward to the next entry in sequence, as per the
		iterator's direction and ordering configuration.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method data!] [arg tuples]]

		This method is a bulk variant of [method add], see
		above. It expects a list of (uuid,value) pairs as
		argument and makes the necessary associations.

	[para]	The result of the method is the empty string. An error
		is thrown if any of the specified uuids is already
		associated with a value, [emph before] any changes are
		made.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method clear]]

		This method removes all uuid from the iterator. After
		the call the instance is empty. The result of the
		method is the empty string.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method reset]]

		This method resets the cursor of the iterator to the
		start position (as per the direction/ordering of the
		iterator). The result of the method is an empty
		string.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method reverse]]

		This method reverses the direction of the iterator.
		The result of the method is an empty string.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method next] [arg n]]

		This method moves the cursor forward by [arg n]
		entries, in the current direction. The result of the
		method is a boolean value which indicates if the step
		moved beyond the end of the iterator ([const true]),
		or not ([const false]).

		The step-length [arg n] must be an integer > 0.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method previous] [arg n]]

		This method moves the cursor backward by [arg n]
		entries, against the current direction. The result of
		the method is a boolean value which indicates if the
		step moved before the start of the iterator
		([const true]), or not ([const false]).

		The step-length [arg n] must be an integer > 0.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method to] [arg location]]

		This method moves the cursor of the iterator to the
		specified absolute [arg location]. See method
		[method location] below for the method which returns
		such locations, and their format.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method direction!] [arg dir]]

		This method sets the direction of iterator relative to
		the sorting order of the values. The possible
		arguments are [const increasing] and
		[const descreasing]. The result of the method is the
		empty string.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method get] [arg uuid]]

		This method locates the value associated with
		[arg uuid] and returns it as its result.

		An error is thrown if [arg uuid] is not known to the
		instance.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method exists] [arg uuid]]

		This method returns a boolean value indicating if the
		[arg uuid] is known to the iterator ([const true]), or
		not ([const false]).

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method size]]

		This method determines the number of uuid/value
		associations stored in the iterator and returns that
		number as the result of the method.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method at] [arg n]]

		This method takes the [arg n] entries of the iterator
		starting at the cursor and going forward, and retrurns
		them as its result. The result is a list of entries,
		each entry represented by a (uuid,value) pair. The
		entries are stored in the order they were taken from
		the iterator.

	[para]	The method does [emph not] move cursor. This is the
		responsibility of the methods [method next] and
		[method previous].

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method direction]]

		This method determines the current direction of the
		iterator relative to the sort order and returns it as
		its result. The two possible results are
		[const increasing] and [const decreasing]

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method location]]

		This method determines the location of the cursor and
		returns it as its result. The format of the result is
		a pair of values, a location code, and details, in
		this order. The possible location codes are

		[list_begin definitions]
		[def [const start]]
			The cursor is before the start of the content.
			The detail value is the empty string.
		[def [const end]]
			The cursor is behind the end of the content.
			The detail value is the empty string.
		[def [const at]]
			The cursor is at a specific entry in the
			iterator. The detail value specifies that
			entry. It is a pair denoting the current
			property value, and the uuid, in this order.
		[list_end]

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method data]]

		This method retrieves the iterator content and returns
		it as a list of (uuid,value)-pairs. This is the same
		format as taken by method [method data!] as input.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method -->] [arg dst]]

		This method copies the contents of the instance to the
		iterator instance [arg dst]. Any preexisting content
		of the destination instance is replaced with the
		information from this iterator.

		The targeted instance has to support the methods
		[method reset], [method clear], [method direction!],
		[method data!], and [method to].

		The result of the method is the empty string.

	[comment {- - -- --- ----- -------- -------------}]
	[call [cmd <instance>] [method :=] [arg src]]

		This method copies the contents of iterator [arg src]
		to this iterator. Any preexisting content of this
		iterator is replaced with the information from the
		source. The source instance has to support the methods
		[method direction], [method data], and
		[method location].

		The result of the method is the empty string.
[list_end]
