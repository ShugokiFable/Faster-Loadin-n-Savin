
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module skse64.hacks.versioning;

import game;


static if (targetedGameArchetype == GameArchetype.ae)
{
	enum uint expectedSKSE64Version = 0x02_02_006_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_1170.dll";
}
else static if (targetedGameArchetype == GameArchetype.ae640)
{
	enum uint expectedSKSE64Version = 0x02_02_003_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_640.dll";
}
else static if (targetedGameArchetype == GameArchetype.se)
{
	enum uint expectedSKSE64Version = 0x02_00_014_0;
	enum string defaultSKSE64DLLName = "skse64_1_5_97.dll";
}
else static if (targetedGameArchetype == GameArchetype.vr)
{
	enum uint expectedSKSE64Version = 0x02_00_00C_0;
	enum string defaultSKSE64DLLName = "sksevr_1_4_15.dll";
}
else static if (targetedGameArchetype == GameArchetype.gog)
{
	enum uint expectedSKSE64Version = 0x02_02_006_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_1179.dll";
}
else static if (targetedGameArchetype == GameArchetype.gog659)
{
	enum uint expectedSKSE64Version = 0x02_02_003_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_659.dll";
}
else
{
	static assert(false);
}


static immutable(wchar[]) defaultSKSE64DLLNameUTF16 = defaultSKSE64DLLName;

