
API
	add:      blob --> uuid
	retrieve: uuid --> blob		[validate uuid]
	channel:  uuid --> channel	[validate uuid]
	names:	  ()   --> list (uuid)
	exists:	  uuid --> boolean
	size:	  ()   --> integer
	clear:	  ()   --> ()
