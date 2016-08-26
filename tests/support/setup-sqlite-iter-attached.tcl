## -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## For sqlite iterators attached to a blob-store for their uuids
## ensure that the blob store contains them.

proc pre-add-entry {uuid key {suffix {}}} {
    # Add a fake entry to the blob table the iterator can find when
    # looking for an uuid. No actual data, just a bit of fake.
    ::test-database$suffix eval {
	INSERT INTO blobs VALUES (NULL,:uuid,:key)
    }
    return
}

# # ## ### ##### ######## ############# #####################
return
