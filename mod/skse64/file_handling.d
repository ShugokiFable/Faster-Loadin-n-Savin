
/+ These definitions are based on the work of the Skyrim Script Extender (SKSE).
   (https://skse.silverlock.org/)
   Full credit goes towards the team behind SKSE, those individuals being:
       Ian Patterson; Stephen Abel; Paul Connelly; Brendan Borthwick
       (ianpatt; behippo; scruggsywuggsy the ferret; purple lunchbox).
   Likewise for any contributors to the Script Extender project not named here.
+/

module skse64.file_handling;

import slack_common.bindings;


struct FileEnumerator
{
	VTable* vtable;
	HANDLE findNextFileHandle;
	WIN32_FIND_DATAA findData;
	bool finished;
	char[MAX_PATH] path;

	struct VTable
	{}
}

