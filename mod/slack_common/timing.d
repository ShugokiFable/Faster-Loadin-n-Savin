
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.timing;

import slack_common.bindings;


struct SystemTimeValue
{
	alias value this;
	long value;

	pragma(inline, true)
	bool isRelative () () const @property scope @safe pure nothrow @nogc
	{
		return this.value < 0;
	}

	pragma(inline, true)
	bool isAbsolute () () const @property scope @safe pure nothrow @nogc
	{
		return this.value >= 0;
	}
}


pragma(inline, true)
SystemTimeValue absoluteSystemTimeFromMilliseconds (ulong milliseconds) @safe pure nothrow @nogc
{
	version (Windows)
	{
		assert(milliseconds < (long.max / 10000));

		return SystemTimeValue(milliseconds * 10000);
	}
	else
	{
		static assert(false);
	}
}


pragma(inline, true)
SystemTimeValue relativeSystemTimeFromMilliseconds (ulong milliseconds) @safe pure nothrow @nogc
{
	version (Windows)
	{
		assert(milliseconds <= (long.max / 10000));

		return SystemTimeValue(milliseconds * -10000);
	}
	else
	{
		static assert(false);
	}
}

