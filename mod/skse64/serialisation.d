
/+ These definitions are based on the work of the Skyrim Script Extender (SKSE).
   (https://skse.silverlock.org/)
   Full credit goes towards the team behind SKSE, those individuals being:
       Ian Patterson; Stephen Abel; Paul Connelly; Brendan Borthwick
       (ianpatt; behippo; scruggsywuggsy the ferret; purple lunchbox).
   Likewise for any contributors to the Script Extender project not named here.
+/

module skse64.serialisation;

import skse64.dll_plugins;


struct Cosave
{
	struct Header
	{
		enum uint magic = 0x45534B53;

		enum SchemaVersion : uint
		{
			latest = v1,
			v1 = 1
		}

		uint signature;
		uint schemaVersion;
		uint skse64Version;
		uint gameVersion;
		uint pluginsWithDataInCosaveCount;
	}

	struct DLLPluginHeader
	{
		uint signature;
		uint recordCount;
		uint size;
	}

	struct RecordHeader
	{
		uint signature;
		uint schemaVersion;
		uint size;
	}
}


struct SerialisationStateForPlugin
{
	SerialisationProvider.ProviderReceiver stateReverter;
	SerialisationProvider.ProviderReceiver stateSaver;
	SerialisationProvider.ProviderReceiver stateLoader;
	SerialisationProvider.FormDeleter formDeleter;

	uint uniqueID;

	bool encounteredDataInLastLoadedSaveFile;
	bool uniqueIDHasBeenAssigned;
}

