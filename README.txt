
API
	add:      blob --> uuid
	retrieve: uuid --> blob		[validate uuid]
	channel:  uuid --> channel	[validate uuid]
	path:	  uuid --> path		[validate uuid][fs only]
	names:	  ()   --> list (uuid)
	exists:	  uuid --> boolean
	size:	  ()   --> integer
	clear:	  ()   --> ()
