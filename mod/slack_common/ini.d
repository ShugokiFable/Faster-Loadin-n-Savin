
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.ini;

import slack_common.memory;
import slack_common.parsing;
import slack_common.text;


struct INISection (Char, bool lossless = false)
{
	Char[] name;

	static if (lossless)
	{
		Char[] precedingText;
		Char[] leadingWhiteSpace;
		Char[] trailingWhiteSpace;
	}
}


struct INIAssignment (Char, bool lossless = false)
{
	Char[] key;
	Char[] value;

	static if (lossless)
	{
		Char[] precedingText;
		Char[] trailingKeyWhiteSpace;
		Char[] leadingValueWhiteSpace;
		Char[] trailingValueWhiteSpace;
	}
}


enum size_t skipINISection = 1;


pragma(inline, true)
bool iniValueAsBoolean (Char) (scope const(Char)[] text, bool defaultValueWhenEmpty = false)
{
	if (text.length == 0)
	{
		return defaultValueWhenEmpty;
	}

	Char v = asciiLowerCase(text[0]);

	if ((v >= '\t') & (v <= '\r'))
	{
		return defaultValueWhenEmpty;
	}

	return (v != 'f') & (v != 'n') & (v != '0');
}


pragma(inline, true)
bool iniValueAsNonNegativeInteger (Int = uint, Char) (
	scope const(Char)[] text,
	scope Int* value
) @trusted
{
	const(Char)* t = text.ptr;
	const(Char)* end = text.endOf;

	if (t >= end)
	{
		return false;
	}

	auto integer = parseAsUnsignedBaseTenInteger!Int(t[0 .. end - t]);

	if ((integer.length == 0) | (integer.overflowed))
	{
		return false;
	}

	*value = integer.value;

	t += integer.length;

	return t >= end;
}


/+ Wherein a simple INI is one which does not support any form of escaping,
   nor comments within section-headers, which allows reading from it to be zero-copy. +/
auto parseSimpleINI (
	bool lossless = false,
	Char,
	SkimSection = size_t delegate (scope const(INISection!(Char, lossless))* section) nothrow @nogc,
	SkimAssignment = void delegate (scope const(INIAssignment!(Char, lossless))* assignment) nothrow @nogc
) (
	scope Char[] ini,
	scope SkimSection skimSection,
	scope SkimAssignment skimAssignment,
	bool skipImplicitSection = false
) @trusted
{
	Char* text = ini.ptr;
	Char* textEnd = ini.endOf;
	Char* c = text;
	Char* section = void;
	Char* sectionEnd = void;
	size_t sectionLength = void;
	Char* key = void;
	Char* keyEnd = void;
	size_t keyLength = void;
	Char* value = void;
	Char* valueEnd = void;
	size_t valueLength = void;
	INISection!(Char, lossless) iniSection = void;
	INIAssignment!(Char, lossless) iniAssignment = void;

	static if (lossless)
	{
		Char* preceding = c;
	}

	if (skipImplicitSection) goto skipToNextSection;
nextDeclaration:
	for (; c < textEnd && ((*c != ';') & ((*c == ' ') | ((*c >= '\t') & (*c <= '\r')))); ++c) {}
	if (c >= textEnd) goto finished;

	if (*c == ';')
	{
	lineComment:
		for (; c < textEnd && ((*c != '\r') & (*c != '\n')); ++c) {}
		if (c >= textEnd) goto finished;
		goto nextDeclaration;
	}

	if (*c == '[')
	{
	sectionHeader:
		static if (lossless) iniSection.precedingText = preceding[0 .. c - preceding];
		++c;
		static if (lossless) preceding = c;
		for (; c < textEnd && ((*c == ' ') | ((*c >= '\t') & (*c <= '\r'))); ++c) {}
		if (c >= textEnd) goto finished;

		static if (lossless) iniSection.leadingWhiteSpace = preceding[0 .. c - preceding];

		section = c;
		sectionEnd = c;

		if (*c == ']')
		{
			static if (lossless) iniSection.trailingWhiteSpace = c[0 .. 0];
			goto endOfSection;
		}

		for (; c < textEnd && (*c != ']'); ++c) {}
		if (c >= textEnd) goto finished;
		sectionEnd = c - (c < textEnd);
		for (; (*sectionEnd == ' ') | ((*sectionEnd >= '\t') & (*sectionEnd <= '\r')); --sectionEnd) {}
		++sectionEnd;
		assert(sectionEnd >= section);
		assert(*c == ']');

		static if (lossless) iniSection.trailingWhiteSpace = sectionEnd[0 .. c - sectionEnd];
	endOfSection:
		++c;
		static if (lossless) preceding = c;
		sectionLength = sectionEnd - section;
		iniSection.name = section[0 .. sectionLength];

		if (skimSection(&iniSection))
		{
		skipToNextSection:
			for (; c < textEnd && ((*c != '[') & (*c != ';')); ++c) {}
			if (c >= textEnd) goto finished;

			if (*c == '[')
			{
				for (Char* h = c;;)
				{
					if (--h < text) goto sectionHeader;

					if ((*h == '\r') | (*h == '\n') | (*h == ']')) goto sectionHeader;

					if ((*h != ' ') & (*h != '\t') & (*h != '\v') & (*h != '\f'))
					{
						++c;
						goto skipToNextSection;
					}
				}
			}
			else
			{
				assert(*c == ';');
				for (; c < textEnd && ((*c != '\r') & (*c != '\n')); ++c) {}
				if (c >= textEnd) goto finished;
				goto skipToNextSection;
			}
		}

		goto nextDeclaration;
	}

	static if (lossless) iniAssignment.precedingText = preceding[0 .. c - preceding];

	key = c;
	/+ A key may begin with an equals-sign. +/
	c += *c == '=';
	for (; c < textEnd && ((*c != ';') & (*c != '=') & (*c != '\r') & (*c != '\n')); ++c) {}
	keyEnd =  c - (c < textEnd);
	if (c >= textEnd) goto keyWithoutValue;
	for (; (key < keyEnd) & ((*keyEnd == ' ') | ((*keyEnd >= '\t') & (*keyEnd <= '\r'))); --keyEnd) {}
	++keyEnd;
	assert(keyEnd >= key);

	static if (lossless) iniAssignment.trailingKeyWhiteSpace = keyEnd[0 .. c - keyEnd];

	if (*c != '=')
	{
		goto _keyWithoutValue;
	keyWithoutValue:
		static if (lossless) iniAssignment.trailingKeyWhiteSpace = keyEnd[0 .. c - keyEnd];
	_keyWithoutValue:
		static if (lossless)
		{
			iniAssignment.leadingValueWhiteSpace = c[0 .. 0];
			iniAssignment.trailingValueWhiteSpace = c[0 .. 0];
		}

		value = null;
		valueEnd = null;
	static if (!lossless)
	keyWithValue:;
	_keyWithValue:
		static if (lossless) preceding = c;
		valueLength = valueEnd - value;
		keyLength = keyEnd - key;
		iniAssignment.key = key[0 .. keyLength];
		iniAssignment.value = value[0 .. valueLength];
		skimAssignment(&iniAssignment);
		goto nextDeclaration;
	static if (lossless)
	keyWithValue:
		static if (lossless)
		{
			iniAssignment.trailingValueWhiteSpace = valueEnd[0 .. c - valueEnd];

			goto _keyWithValue;
		}
	}

	++c;
	static if (lossless) preceding = c;
	for (; (c < textEnd) && ((*c == ' ') | (*c == '\t') | (*c == '\v') | (*c == '\f')); ++c) {}
	static if (lossless) iniAssignment.leadingValueWhiteSpace = preceding[0 .. c - preceding];
	value = c;
	valueEnd = c;
	if (c >= textEnd) goto keyWithValue;
	for (; c < textEnd && ((*c != ';') & (*c != '\r') & (*c != '\n')); ++c) {}
	valueEnd =  c - (c < textEnd);
	if (c >= textEnd) goto keyWithValue;
	for (; (value < valueEnd) & ((*valueEnd == ' ') | ((*valueEnd >= '\t') & (*valueEnd <= '\r'))); --valueEnd) {}
	++valueEnd;
	assert(valueEnd >= value);

	goto keyWithValue;
finished:
	static if (lossless)
	{
		return preceding[0 .. c - preceding];
	}
}


@safe pure nothrow @nogc unittest
{
	immutable(char)[] ini = "
		the  =  implicit section \t
		[ \v Foo \t ]  [Still Foo!]  sure why not put a key here? = I hate parsing.
		; A comment!
		ohno\x20\x20
		ohyes; more comment
		foo = abc
		baz =
		baz=\x20\x20
		baz=; with a comment
		=bar = 1 2 3
		= x\ty\tz = \t1\t2\t3\t
		[this section is skipped]
		a = 0
		b = 1 [not a section]
		; c = 4 [also not a section]
		c [still not a section] = 3
		d = 4
		[]
		lol=empty=section:)
		[ ];;;
		[ evil and ; ]
		  very twisted user]
		ihateyou = [developer]\f
		; THE END
	";

	/+ We could support comments within section-headers,
	   but I'd rather not because that would make simple INI reading not-zero-copy. +/

	uint sectionCounter = void;
	uint assignmentCounter = void;

	void test (bool lossless) ()
	{
		sectionCounter = 0;
		assignmentCounter = 0;

		alias skimSection = (scope const(INISection!(immutable(char), lossless))* s)
		{
			final switch (sectionCounter++)
			{
			case 0:
				assert(s.name == "Foo");
				static if (lossless)
				{
					assert(s.precedingText == "\n\t\t");
					assert(s.leadingWhiteSpace == " \v ");
					assert(s.trailingWhiteSpace == " \t ");
				}
				return 0;
			case 1:
				assert(s.name == "Still Foo!");
				static if (lossless)
				{
					assert(s.precedingText == "  ");
					assert(s.leadingWhiteSpace == "");
					assert(s.trailingWhiteSpace == "");
				}
				return 0;
			case 2:
				assert(s.name == "this section is skipped");
				static if (lossless)
				{
					assert(s.precedingText == "\n\t\t");
					assert(s.leadingWhiteSpace == "");
					assert(s.trailingWhiteSpace == "");
				}
				return skipINISection;
			case 3:
				assert(s.name == "");
				static if (lossless)
				{
					assert(s.precedingText == "\n\t\ta = 0\n\t\tb = 1 [not a section]\n\t\t; c = 4 [also not a section]\n\t\tc [still not a section] = 3\n\t\td = 4\n\t\t");
					assert(s.leadingWhiteSpace == "");
					assert(s.trailingWhiteSpace == "");
				}
				return 0;
			case 4:
				assert(s.name == "");
				static if (lossless)
				{
					assert(s.precedingText == "\n\t\t");
					assert(s.leadingWhiteSpace == " ");
					assert(s.trailingWhiteSpace == "");
				}
				return 0;
			case 5:
				assert(s.name == "evil and ;");
				static if (lossless)
				{
					assert(s.precedingText == ";;;\n\t\t");
					assert(s.leadingWhiteSpace == " ");
					assert(s.trailingWhiteSpace == " ");
				}
				return 0;
			}
		};

		alias skimAssignment = (scope const(INIAssignment!(immutable(char), lossless))* a)
		{
			final switch (assignmentCounter++)
			{
			case 0:
				assert(a.key == "the");
				assert(a.value == "implicit section");
				static if (lossless)
				{
					assert(a.precedingText == "\n\t\t");
					assert(a.trailingKeyWhiteSpace == "  ");
					assert(a.leadingValueWhiteSpace == "  ");
					assert(a.trailingValueWhiteSpace == " \t");
				}
				break;
			case 1:
				assert(a.key == "sure why not put a key here?");
				assert(a.value == "I hate parsing.");
				static if (lossless)
				{
					assert(a.precedingText == "  ");
					assert(a.trailingKeyWhiteSpace == " ");
					assert(a.leadingValueWhiteSpace == " ");
					assert(a.trailingValueWhiteSpace == "");
				}
				break;
			case 2:
				assert(a.key == "ohno");
				assert(a.value is null);
				static if (lossless)
				{
					assert(a.precedingText == "\n\t\t; A comment!\n\t\t");
					assert(a.trailingKeyWhiteSpace == "\x20\x20");
					assert(a.leadingValueWhiteSpace == "");
					assert(a.trailingValueWhiteSpace == "");
				}
				break;
			case 3:
				assert(a.key == "ohyes");
				assert(a.value is null);
				static if (lossless)
				{
					assert(a.precedingText == "\n\t\t");
					assert(a.trailingKeyWhiteSpace == "");
					assert(a.leadingValueWhiteSpace == "");
					assert(a.trailingValueWhiteSpace == "");
				}
				break;
			case 4:
				assert(a.key == "foo");
				assert(a.value == "abc");
				static if (lossless)
				{
					assert(a.precedingText == "; more comment\n\t\t");
					assert(a.trailingKeyWhiteSpace == " ");
					assert(a.leadingValueWhiteSpace == " ");
					assert(a.trailingValueWhiteSpace == "");
				}
				break;
			case 5:
				assert(a.key == "baz");
				assert(a.value == "");
				static if (lossless)
				{
					assert(a.precedingText == "\n\t\t");
					assert(a.trailingKeyWhiteSpace == " ");
					assert(a.leadingValueWhiteSpace == "");
					assert(a.trailingValueWhiteSpace == "");
				}
				break;
			case 6:
				assert(a.key == "baz");
				assert(a.value == "");
				assert(a.key == "baz");
				assert(a.value == "");
				static if (lossless)
				{
					assert(a.precedingText == "\n\t\t");
					assert(a.trailingKeyWhiteSpace == "");
					assert(a.leadingValueWhiteSpace == "\x20\x20");
					assert(a.trailingValueWhiteSpace == "");
				}
				break;
			case 7:
				assert(a.key == "baz");
				assert(a.value == "");
				static if (lossless)
				{
					assert(a.precedingText == "\n\t\t");
					assert(a.trailingKeyWhiteSpace == "");
					assert(a.leadingValueWhiteSpace == "");
					assert(a.trailingValueWhiteSpace == "");
				}
				break;
			case 8:
				assert(a.key == "=bar");
				assert(a.value == "1 2 3");
				static if (lossless)
				{
					assert(a.precedingText == "; with a comment\n\t\t");
					assert(a.trailingKeyWhiteSpace == " ");
					assert(a.leadingValueWhiteSpace == " ");
					assert(a.trailingValueWhiteSpace == "");
				}
				break;
			case 9:
				assert(a.key == "= x\ty\tz");
				assert(a.value == "1\t2\t3");
				static if (lossless)
				{
					assert(a.precedingText == "\n\t\t");
					assert(a.trailingKeyWhiteSpace == " ");
					assert(a.leadingValueWhiteSpace == " \t");
					assert(a.trailingValueWhiteSpace == "\t");
				}
				break;
			case 10:
				assert(a.key == "lol");
				assert(a.value == "empty=section:)");
				static if (lossless)
				{
					assert(a.precedingText == "\n\t\t");
					assert(a.trailingKeyWhiteSpace == "");
					assert(a.leadingValueWhiteSpace == "");
					assert(a.trailingValueWhiteSpace == "");
				}
				break;
			case 11:
				assert(a.key == "very twisted user]");
				assert(a.value is null);
				static if (lossless)
				{
					assert(a.precedingText == "\n\t\t  ");
					assert(a.trailingKeyWhiteSpace == "");
					assert(a.leadingValueWhiteSpace == "");
					assert(a.trailingValueWhiteSpace == "");
				}
				break;
			case 12:
				assert(a.key == "ihateyou");
				assert(a.value == "[developer]");
				static if (lossless)
				{
					assert(a.precedingText == "\n\t\t");
					assert(a.trailingKeyWhiteSpace == " ");
					assert(a.leadingValueWhiteSpace == " ");
					assert(a.trailingValueWhiteSpace == "\f");
				}
				break;
			}
		};

		static if (lossless)
		{
			immutable(char)[] remaining = parseSimpleINI!lossless(ini, skimSection, skimAssignment);
			assert(remaining == "\n\t\t; THE END\n\t");
		}
		else
		{
			parseSimpleINI!lossless(ini, skimSection, skimAssignment);
		}

		assert(sectionCounter == 6);
		assert(assignmentCounter == 13);
	}

	test!false;
	test!true;

	ini = "
		a = a
		b = b
		[section] = key == value
	";

	sectionCounter = 0;
	assignmentCounter = 0;

	parseSimpleINI(
		ini,
		(scope const(INISection!(immutable(char)))* s)
		{
			final switch (sectionCounter++)
			{
			case 0:
				assert(s.name == "section");
				return 0;
			}
		},
		(scope const(INIAssignment!(immutable(char)))* a)
		{
			final switch (assignmentCounter++)
			{
			case 0:
				assert(a.key == "= key");
				assert(a.value == "= value");
				break;
			}
		},
		true
	);

	assert(sectionCounter == 1);
	assert(assignmentCounter == 1);
}

