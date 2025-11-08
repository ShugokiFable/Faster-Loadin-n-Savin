
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.versions;


version (BigEndian)
{
	enum bool bigEndianTarget = true;
	enum bool littleEndianTarget = false;
}
else
{
	enum bool bigEndianTarget = false;
	enum bool littleEndianTarget = true;
}


version (X86_64)
{
	enum bool x86X = true;
	enum bool x86_64 = true;
	enum bool x86_32 = false;
	enum bool ARM = false;
	enum bool ARM32 = false;
	enum bool ARM64 = false;
}
else version (X86)
{
	enum bool x86X = true;
	enum bool x86_64 = false;
	enum bool x86_32 = true;
	enum bool ARM = false;
	enum bool ARM32 = false;
	enum bool ARM64 = false;
}
else version (AArch64)
{
	enum bool x86X = false;
	enum bool x86_64 = false;
	enum bool x86_32 = false;
	enum bool ARM = true;
	enum bool ARM32 = false;
	enum bool ARM64 = true;
}
else version (ARM)
{
	enum bool x86X = false;
	enum bool x86_64 = false;
	enum bool x86_32 = false;
	enum bool ARM = true;
	enum bool ARM32 = true;
	enum bool ARM64 = false;
}
else
{
	enum bool x86X = false;
	enum bool x86_64 = false;
	enum bool x86_32 = false;
	enum bool ARM = false;
	enum bool ARM32 = false;
	enum bool ARM64 = false;
}

version (LDC)
{
	enum bool LDC = true;
	enum bool GDC = false;
	enum bool DMD = false;
}
else version (GNU)
{
	enum bool LDC = false;
	enum bool GDC = true;
	enum bool DMD = false;
}
else
{
	enum bool LDC = false;
	enum bool GDC = false;
	enum bool DMD = true;
}


version (LDC)
{
	public import ldc.attributes : llvmAttr;
}
else
{
	struct llvmAttr
	{
		string key;
		string value;
	}
}

