
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.integers;

import core.bitop : bswap;

import slack_common.versions;

import std.meta : AliasSeq;
import std.traits : Unqual;

public import std.typecons : Flag, No, Yes;


alias UIntsFittingSizeOf = AliasSeq!(ubyte, ubyte, ushort, uint, uint, ulong, ulong, ulong, ulong);
alias IntsFittingSizeOf = AliasSeq!(byte, byte, short, int, int, long, long, long, long);


version (LDC)
{
	enum string[] llvmIRIntsBySizeOf = ["[0 x i8]", "i8", "i16", "i24", "i32", "i40", "i48", "i56", "i64", "i72", "i80", "i88", "i96", "i104", "i112", "i120", "i128"];
}


pragma(inline, true)
package ubyte swapByte () (ubyte value)
{
	return value;
}

/+ core.bitop.byteswap won't work for BetterC. +/
pragma(inline, true)
package Short swapShort (Short) (Short value)
if (is(Unqual!Short == ushort) || is(Unqual!Short == short))
{
	return cast(Short) (((value >> 8) & 0xFF) | ((value << 8) & 0xFF00));
}


alias endianSwap = swapByte!();
alias endianSwap = swapShort!ushort;
alias endianSwap = swapShort!short;
alias endianSwap = bswap;


pragma(inline, true)
uint popcount (T) (T value)
{
	if (__ctfe)
	{
		import core.bitop : popcnt;

		return popcnt(value);
	}
	else
	{
		version (LDC)
		{
			import ldc.intrinsics : llvm_ctpop;
			return cast(uint) llvm_ctpop(value);
		}
		else version (GNU)
		{
			static if (T.sizeof <= 4)
			{
				import gcc.builtins : __builtin_popcount;
				return cast(T) __builtin_popcount(value);
			}
			else
			{
				import gcc.builtins : __builtin_popcountll;
				return __builtin_popcountll(value);
			}
		}
		else
		{
			import core.bitop : _popcnt;
			return _popcnt(value);
		}
	}
}


pragma(inline, true)
uint leastSetBitIndex (Flag!"definedForZero" definedForZero = Yes.definedForZero, T) (T value)
{
	import core.bitop : bsf;

	if (__ctfe)
	{
		enum uint operandSize = T.sizeof << 3;

		return value == 0 ? operandSize : cast(uint) bsf(value);
	}
	else
	{
		static if (LDC)
		{
			import ldc.intrinsics : llvm_cttz;
			return cast(uint) llvm_cttz(value, !cast(bool) definedForZero);
		}
		else static if (GDC)
		{
			static if (T.sizeof <= 4)
			{
				import gcc.builtins : __builtin_ctz;
				auto index = cast(uint) __builtin_ctz(value) ^ operandSizeLessOne;
			}
			else
			{
				import gcc.builtins : __builtin_ctzll;
				auto index = cast(uint) __builtin_ctzll(value) ^ operandSizeLessOne;
			}

			static if (definedForZero)
			{
				enum uint operandSize = T.sizeof << 3;
				return value == 0 ? operandSize : index;
			}
			else
			{
				return index;
			}
		}
		else
		{
			auto index = cast(uint) bsf(value);

			static if (definedForZero)
			{
				enum uint operandSize = T.sizeof << 3;
				return value == 0 ? operandSize : index;
			}
			else
			{
				return index;
			}
		}
	}
}


pragma(inline, true)
uint greatestSetBitIndex (Flag!"definedForZero" definedForZero = Yes.definedForZero, T) (T value)
{
	import core.bitop : bsr;

	enum uint operandSize = T.sizeof << 3;

	if (__ctfe)
	{
		return value == 0 ? operandSize : cast(uint) bsr(value);
	}

	version (LDC)
	{
		import ldc.intrinsics : llvm_ctlz;

		enum uint operandSizeLessOne = (T.sizeof << 3) - 1;

		auto count = cast(uint) llvm_ctlz(value, false) ^ operandSizeLessOne;

		static if (definedForZero)
		{
			return value == 0 ? operandSize : count;
		}
		else
		{
			return count;
		}
	}
	else version (GNU)
	{
		enum uint operandSizeLessOne = (T.sizeof << 3) - 1;

		static if (T.sizeof <= 4)
		{
			import gcc.builtins : __builtin_clz;
			auto count = cast(uint) __builtin_clz(value) ^ operandSizeLessOne;
		}
		else
		{
			import gcc.builtins : __builtin_clzll;
			auto count = cast(uint) __builtin_clzll(value) ^ operandSizeLessOne;
		}

		static if (definedForZero)
		{
			return value == 0 ? operandSize : count;
		}
		else
		{
			return count;
		}
	}
	else
	{
		auto count = cast(uint) bsr(value);

		static if (definedForZero)
		{
			return value == 0 ? operandSize : count;
		}
		else
		{
			return count;
		}
	}
}


pragma(inline, true)
uint leadingZeroCount (Flag!"definedForZero" definedForZero = Yes.definedForZero, T) (T value)
{
	import core.bitop : bsr;

	if (__ctfe)
	{
		enum uint operandSize = T.sizeof << 3;
		enum uint operandSizeLessOne = operandSize - 1;

		return value == 0 ? operandSize : (cast(uint) bsr(value) ^ operandSizeLessOne);
	}
	else
	{
		static if (LDC)
		{
			import ldc.intrinsics : llvm_ctlz;
			return cast(uint) llvm_ctlz(value, !cast(bool) definedForZero);
		}
		else static if (GDC)
		{
			static if (T.sizeof <= 4)
			{
				import gcc.builtins : __builtin_clz;
				auto count = cast(uint) __builtin_clz(value);
			}
			else
			{
				import gcc.builtins : __builtin_clzll;
				auto count = cast(uint) __builtin_clzll(value);
			}

			static if (definedForZero)
			{
				enum uint operandSize = T.sizeof << 3;
				return value == 0 ? operandSize : count;
			}
			else
			{
				return count;
			}
		}
		else
		{
			enum uint operandSize = T.sizeof << 3;
			enum uint operandSizeLessOne = operandSize - 1;

			auto count = cast(uint) bsr(value) ^ operandSizeLessOne;

			static if (definedForZero)
			{
				return value == 0 ? operandSize : count;
			}
			else
			{
				return count;
			}
		}
	}
}


pragma(inline, true)
bool isPowerOfTwo (I) (I value)
in (value > 0)
{
	return value.popcount == 1;
}


pragma(inline, true)
uint integralLog2 (I) (I value)
{
	return value.greatestSetBitIndex!(No.definedForZero);
}


pragma(inline, true)
I conditionallySetOrClearMask (I, Mask) (I value, Mask mask, bool set)
{
	/+ Courtesy of https://graphics.stanford.edu/~seander/bithacks.html#ConditionalSetOrClearBitsWithoutBranching. +/
	return cast(I) ((value & ~mask) | (-ptrdiff_t(set) & mask));
}


pragma(inline, true)
ref I conditionallyMutateMask (I, Mask) (return scope ref I value, Mask mask, bool set)
{
	/+ Courtesy of https://graphics.stanford.edu/~seander/bithacks.html#ConditionalSetOrClearBitsWithoutBranching. +/
	return value = cast(I) ((value & ~mask) | (-ptrdiff_t(set) & mask));
}


pragma(inline, true)
I alignUpTo (I, A) (I offset, A alignment)
if (!is(I : P*, P))
in (alignment > 0)
in (alignment <= I.max)
{
	return offset.roundUpToMultipleOfPowerOfTwo(cast(I) alignment);
}


pragma(inline, true)
T* alignUpTo (T) (T* pointer, size_t alignment = T.alignof) @trusted
{
	return cast(T*) alignUpTo(cast(size_t) pointer, alignment);
}


pragma(inline, true)
I alignDownTo (I, A) (I offset, A alignment)
if (!is(I : P*, P))
in (alignment > 0)
in (alignment <= I.max)
{
	return offset.roundDownToMultipleOfPowerOfTwo(alignment);
}


pragma(inline, true)
T* alignDownTo (T) (T* pointer, size_t alignment = T.alignof) @trusted
{
	return cast(T*) alignDownTo(cast(size_t) pointer, alignment);
}


pragma(inline, true)
I roundUpToMultipleOfPowerOfTwo (I) (I value, I factor)
in (factor > 0)
in (factor.isPowerOfTwo)
{
	return cast(I) ((value + factor - 1) & ~(factor - 1));
}


pragma(inline, true)
I roundDownToMultipleOfPowerOfTwo (I) (I value, I factor)
in (factor > 0)
in (factor.isPowerOfTwo)
{
	return cast(I) (value & ~(factor - 1));
}


pragma(inline, true)
I roundUpToPowerOfTwo (I) (I value)
{
	uint exponent = value.greatestSetBitIndex!(No.definedForZero);
	I roundedUp = cast(I) (I(1) << (exponent + !value.isPowerOfTwo));

	return value != 0 ? roundedUp : 1;
}

