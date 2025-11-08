
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module skse64.hacks.offsets;

import game;


enum VersionedOffsets versionedOffsets = {
	globalSKSE64Provider: {ae: 0x0000b480, se: 0x0000dad8, vr: 0x0000de20, gog: 0x0000b140}, /+ .rdata +/
	cosaveSavePath: {ae: 0x00001b18, se: 0x00001b78, vr: 0x000141e0, gog: 0x00001b18}, /+ .data +/
	cosaveAwarePlugins: {ae: 0x00010d88, se: 0x000123a8, vr: 0x000141c8, gog: 0x00010bd8}, /+ .data +/
	initialiseCall: {ae: 0x00088c44, se: 0x00087240, vr: 0x0009c140, gog: 0x0008afb4}, /+ .text +/
	createCosave: {ae: 0x000874f0, se: 0x000854e0, vr: 0x0009af50, gog: 0x00089820}, /+ .text +/
	restoreCosave: {ae: 0x00087700, se: 0x000856f0, vr: 0x0009b230, gog: 0x00089a30}, /+ .text +/
	createCosaveCall: {ae: 0x0000e8df, se: 0x0000e6ff, vr: 0x0000f6af, gog: 0x0000e85f}, /+ .text +/
	restoreCosaveCall: {ae: 0x0000e90f, se: 0x0000e72f, vr: 0x0000f6df, gog: 0x0000e88f}, /+ .text +/
	consolePrint: {ae: 0x00002f70, se: 0x00002e60, vr: 0x000034b0, gog: 0x00002f50}, /+ .text +/
};


struct VersionedOffset
{
	/+ The latest version of the Anniversary Edition. (Technically still the Special Edition, just a newer version). +/
	uint ae;
	/+ The latest version of the Special Edition. +/
	uint se;
	/+ The latest version of the VR edition. +/
	uint vr;
	/+ The latest version of the GOG edition. (Which is just the Anniversary Edition, but with a different version number,
	   because three versions aren't enough!). +/
	uint gog;
}


struct VersionedOffsets
{
	VersionedOffset globalSKSE64Provider;
	VersionedOffset cosaveSavePath;
	VersionedOffset cosaveAwarePlugins;
	VersionedOffset initialiseCall;
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
		mixin("uint ", member, ";");
	}
}


enum SKSE64Offsets skse64Offsets = ()
{
	SKSE64Offsets offsets;

	enum size_t count = versionedOffsets.tupleof.length;

	static foreach (index; 0 .. count)
	{
		offsets.tupleof[index] = __traits(getMember, versionedOffsets.tupleof[index], targetedGameTag);
	}

	return offsets;
}();

