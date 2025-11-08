
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.byte_sizes;

ulong B (ulong value) @safe pure nothrow @nogc
{
	return value << 0;
}

ulong KB (ulong value) @safe pure nothrow @nogc
in (value < (ulong(1) << 54))
{
	return value << 10;
}

ulong MB (ulong value) @safe pure nothrow @nogc
in (value < (ulong(1) << 44))
{
	return value << 20;
}

ulong GB (ulong value) @safe pure nothrow @nogc
in (value < (ulong(1) << 34))
{
	return value << 30;
}

ulong TB (ulong value) @safe pure nothrow @nogc
in (value < (ulong(1) << 24))
{
	return value << 40;
}

ulong PB (ulong value) @safe pure nothrow @nogc
in (value < (ulong(1) << 14))
{
	return value << 50;
}

ulong EB (ulong value) @safe pure nothrow @nogc
in (value < (ulong(1) << 4))
{
	return value << 60;
}

