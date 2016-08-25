## -*- tcl -*-
## (c) 2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################

rename new-iter new-iter.base

proc new-iter {{suffix {}}} {
    new-store $suffix             ;# ==> ::test-database$suffix blobs
    # Create the sidecar ...
    ::test-database$suffix eval {
	CREATE TABLE aside
	( id  INTEGER PRIMARY KEY AUTOINCREMENT
	, str TEXT NOT NULL UNIQUE
	);
	--
	-- Fill the sidecar. All values used by the tests have to exist.
	--
	INSERT INTO aside
	VALUES ( 0,"baron")
	,      ( 1,"baroness")
	,      ( 2,"count")
	,      ( 3,"countess")
	,      ( 4,"dame")
	,      ( 5,"duchess")
	,      ( 6,"duke")
	,      ( 7,"emperor")
	,      ( 8,"empress")
	,      ( 9,"graf")
	,      (10,"heir")
	,      (11,"heiress")
	,      (12,"herr")
	,      (13,"king")
	,      (14,"lady")
	,      (15,"lord")
	,      (16,"prince")
	,      (17,"princess")
	,      (18,"queen")
	,      (19,"woman")
	-- -----------------------------
	,      (20, "KEY")
	,      (21, "KEX")
	,      (22, "FOO")
	;
    }
    [iter-class] create test-iter$suffix ::test-database$suffix \
	-blob-table   blobs \
	-iter-table   iter  \
	-value-table  aside \
	-value-column str
    return
}

# # ## ### ##### ######## ############# #####################
return
