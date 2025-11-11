
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.pe;

import slack_common.bindings;


struct PESections
{
	alias sections this;

	union
	{
		ubyte[][3] sections;

		struct
		{
			ubyte[] text;
			ubyte[] data;
			ubyte[] rdata;
		}
	}
}


size_t findSectionsOfPE64 (scope void* image, scope PESections* sections) @trusted nothrow @nogc
{
	auto dosStub = cast(IMAGE_DOS_HEADER*) image;
	auto headers = cast(IMAGE_NT_HEADERS64*) (image + dosStub.e_lfanew);

	ushort sectionCount = headers.FileHeader.NumberOfSections;

	auto sectionTable = cast(IMAGE_SECTION_HEADER*) (
		cast(void*) &headers.OptionalHeader + headers.FileHeader.SizeOfOptionalHeader
	);
	auto section = sectionTable;
	auto sectionTableEnd = sectionTable + sectionCount;

	enum string slice = q{(cast(ubyte*) (image + section.VirtualAddress))[0 .. section.VirtualSize]};

	size_t missing = 0b111;

	for (; section < sectionTableEnd; ++section)
	{
		if (section.Name == ".text\0\0\0")
		{
			missing &= ~(1 << 0);
			sections.text = mixin(slice);
		}
		else if (section.Name == ".data\0\0\0")
		{
			missing &= ~(1 << 1);
			sections.data = mixin(slice);
		}
		else if (section.Name == ".rdata\0\0")
		{
			missing &= ~(1 << 2);
			sections.rdata = mixin(slice);
		}
	}

	return missing;
}

