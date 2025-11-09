
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module skse64.hacks.offsets;

import game;


enum VersionedOffsets versionedOffsets = {
	globalSKSE64Provider: {ae: 0x0000b480, ae640: 0x0000b470, se: 0x0000dad8, vr: 0x0000de20, gog: 0x0000b140, gog659: 0x0000b488}, /+ .rdata +/
	      cosaveSavePath: {ae: 0x00001b18, ae640: 0x00001b18, se: 0x00001b78, vr: 0x000141e0, gog: 0x00001b18, gog659: 0x00001b18}, /+ .data +/
	  cosaveAwarePlugins: {ae: 0x00010d88, ae640: 0x00010d40, se: 0x000123a8, vr: 0x000141c8, gog: 0x00010bd8, gog659: 0x00010d30}, /+ .data +/
	      initialiseCall: {ae: 0x00088c44, ae640: 0x00088a84, se: 0x00000000, vr: 0x0009c140, gog: 0x0008afb4, gog659: 0x00088c54}, /+ .text +/
	initialiseTailReturn: {ae: 0x00000000, ae640: 0x00000000, se: 0x00087227, vr: 0x00000000, gog: 0x00000000, gog659: 0x00000000}, /+ .text +/
	   supplyProviderLEA: {ae: 0x00080fa4, ae640: 0x00080de4, se: 0x0007fc24, vr: 0x00094e24, gog: 0x00082fb4, gog659: 0x00080fa4}, /+ .text +/
	        createCosave: {ae: 0x000874f0, ae640: 0x00087330, se: 0x000854e0, vr: 0x0009af50, gog: 0x00089820, gog659: 0x00087510}, /+ .text +/
	       restoreCosave: {ae: 0x00087700, ae640: 0x00087540, se: 0x000856f0, vr: 0x0009b230, gog: 0x00089a30, gog659: 0x00087720}, /+ .text +/
	    createCosaveCall: {ae: 0x0000e8df, ae640: 0x0000e82f, se: 0x0000e6ff, vr: 0x0000f6af, gog: 0x0000e85f, gog659: 0x0000e67f}, /+ .text +/
	   restoreCosaveCall: {ae: 0x0000e90f, ae640: 0x0000e85f, se: 0x0000e72f, vr: 0x0000f6df, gog: 0x0000e88f, gog659: 0x0000e6af}, /+ .text +/
	        consolePrint: {ae: 0x00002f70, ae640: 0x00002f50, se: 0x00002e60, vr: 0x000034b0, gog: 0x00002f50, gog659: 0x00002f50}, /+ .text +/
};


struct VersionedOffset
{
	/+ The latest version of the Anniversary Edition. (Technically still the Special Edition, just a newer version). +/
	uint ae;
	/+ Version 1.6.640 of the Anniversary Edition. +/
	uint ae640;
	/+ The latest version of the Special Edition. +/
	uint se;
	/+ The latest version of the VR edition. +/
	uint vr;
	/+ The latest version of the GOG edition. (Which is just the Anniversary Edition, but with a different version number,
	   because three versions aren't enough!). +/
	uint gog;
	/+ Version 1.6.659 of the GOG edition. +/
	uint gog659;
}


struct VersionedOffsets
{
	VersionedOffset globalSKSE64Provider;
	VersionedOffset cosaveSavePath;
	VersionedOffset cosaveAwarePlugins;
	VersionedOffset initialiseCall;
	VersionedOffset initialiseTailReturn;
	VersionedOffset supplyProviderLEA;
	VersionedOffset createCosave;
	VersionedOffset restoreCosave;
	VersionedOffset createCosaveCall;
	VersionedOffset restoreCosaveCall;
	VersionedOffset consolePrint;
}


struct SKSE64Offsets
{
	static foreach (member; __traits(allMembers, VersionedOffsets))
	{
		static if (__traits(getMember, __traits(getMember, versionedOffsets, member), targetedGameTag) != 0)
		{
			mixin("uint ", member, ";");
		}
	}
}


enum SKSE64Offsets skse64Offsets = ()
{
	SKSE64Offsets offsets;

	static foreach (member; __traits(allMembers, SKSE64Offsets))
	{
		__traits(getMember, offsets, member) = __traits(getMember, __traits(getMember, versionedOffsets, member), targetedGameTag);
	}

	return offsets;
}();

