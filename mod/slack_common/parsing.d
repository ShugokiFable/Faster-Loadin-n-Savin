
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.parsing;


pragma(inline, true)
auto parseAsUnsignedBaseTenInteger (Int, Char) (scope const(Char)[] text) @safe pure nothrow @nogc
{
	enum Int overflowThreshold = cast(Int) Int.max / 10;

	static struct Result
	{
		Int value;
		ubyte length;
		bool overflowed;
	}

	Int value;

	for (ubyte index = 0;; ++index)
	{
		Char c = void;

		if (index < text.length && (((c = text[index]) >= '0') & (c <= '9')))
		{
			if (value > overflowThreshold)
			{
				return Result(value, cast(ubyte) (index + 1), true);
			}

			value *= 10;
			value += c - '0';
		}
		else
		{
			return Result(value, index, false);
		}
	}
}

