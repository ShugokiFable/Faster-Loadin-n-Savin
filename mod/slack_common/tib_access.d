
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

/+ This module is in a different style to the rest of the codebase, because I wrote it in mid 2023. +/
module slack_common.tib_access;

public import slack_common.memory : pointerAndByteOffset;

import slack_common.bindings;
import slack_common.integers;
import slack_common.memory;
import slack_common.versions;

import std.meta : Alias, AliasSeq;
import std.traits : Unqual;
import std.typecons : Flag, No, Yes;

version (LDC)
{
	import ldc.attributes;
	import ldc.intrinsics;
	import ldc.llvmasm;
}


version(Windows)
{
	uint getLastError () @trusted nothrow @nogc
	{
		return readFromTIB!(uint, pointerAndByteOffset(13, 0));
	}


	void setLastError (uint value) @trusted nothrow @nogc
	{
		return writeToTIB!(uint, pointerAndByteOffset(13, 0))(value);
	}


	private template AliasSlice (size_t start, size_t end, T...)
	{
		alias AliasSlice = T[start .. end];
	}


	enum void* weaklyPureTIBAccess = null;


	static if (x86X)
	{
		struct X86TIBReference
		{}

		version (DigitalMars)
		{
			struct TIBReference
			{}
		}
		else
		{
			alias TIBReference = X86TIBReference[0];

			static assert(TIBReference.sizeof == 0);
		}

		T read (T, alias displacement = void, alias scale = void, Flag!"purely" purely = No.purely) (
			scope TIBReference tibReference,
			scope AliasSeq!(void*)[0 .. purely] makeWeaklyPure,
			AliasSeq!(int)[0 .. is(displacement == void)] runtimeDisplacement,
			AliasSeq!(uint)[0 .. !is(scale == void)] index
		)
		{
			return readFromTIB!(T, displacement, scale, purely)(makeWeaklyPure, runtimeDisplacement, index);
		}

		void write (T, alias displacement = void, alias scale = void, Flag!"purely" purely = No.purely) (
			scope TIBReference tibReference,
			T value,
			scope AliasSeq!(void*)[0 .. purely] makeWeaklyPure,
			AliasSeq!(int)[0 .. is(displacement == void)] runtimeDisplacement,
			AliasSeq!(uint)[0 .. !is(scale == void)] index
		)
		{
			writeToTIB!(T, displacement, scale, purely)(makeWeaklyPure, value, runtimeDisplacement, index);
		}
	}
	else static if (ARM)
	{
		struct ARMTIBReference
		{
			void* base;
		}

		alias TIBReference = ARMTIBReference;

		T read (T, alias displacement = void, alias scale = void, Flag!"purely" purely = No.purely) (
			scope TIBReference tibReference,
			scope AliasSeq!(void*)[0 .. purely] makeWeaklyPure,
			AliasSeq!(int)[0 .. is(displacement == void)] runtimeDisplacement,
			AliasSeq!(uint)[0 .. !is(scale == void)] index
		)
		{
			int address = mixin(calculateTIBDisplacementAddress);
			auto pointer = mixin(makeTIBDisplacementPointer!(q{T*}, q{tibReference.base}));

			return *pointer;
		}

		void write (T, alias displacement = void, alias scale = void, Flag!"purely" purely = No.purely) (
			scope TIBReference tibReference,
			T value,
			scope AliasSeq!(void*)[0 .. purely] makeWeaklyPure,
			AliasSeq!(int)[0 .. is(displacement == void)] runtimeDisplacement,
			AliasSeq!(uint)[0 .. !is(scale == void)] index
		)
		{
			int address = mixin(calculateTIBDisplacementAddress);
			auto pointer = mixin(makeTIBDisplacementPointer!(q{T*}, q{tibReference.base}));

			*pointer = value;
		}

		private enum string makeTIBDisplacementPointer (string type, string base) = (
			"cast(" ~ type ~ ") (" ~ base ~ " + address)"
		);
	}


	version (LDC)
	{
		private enum string calculateTIBDisplacementAddress = `
			mixin(
				is(scale == void) ? "" : "index[0] * scale + ",
				is(displacement == void) ? "runtimeDisplacement[0]" : "displacement"
			)
		`;
	}


	TIBReference referToTIB () @safe nothrow @nogc
	{
		return referToTIB!();
	}


	TIBReference referToTIB (Flag!"purely" purely = No.purely) (
		scope AliasSlice!(0, purely, void*) makeWeaklyPure
	) @safe nothrow @nogc
	{
		static if (x86X)
		{
			version (DigitalMars)
			{
				return TIBReference();
			}
			else
			{
				return [];
			}
		}
		else static if (ARM)
		{
			return TIBReference(addressOfTIB!purely(makeWeaklyPure));
		}
	}


	alias readFromTIB (
		T,
		alias displacement = void,
		alias scale = void,
		Flag!"purely" purely = No.purely
	) = accessTIB!(T, displacement, scale, purely).access!"read";


	alias writeToTIB (
		T,
		alias displacement = void,
		alias scale = void,
		Flag!"purely" purely = No.purely
	) = accessTIB!(T, displacement, scale, purely).access!"write";


	template accessTIB (T, alias displacement = void, alias scale = void, Flag!"purely" purely = No.purely)
	if (
		   T.sizeof > 0 && T.sizeof <= 8 && T.sizeof.isPowerOfTwo
		&& (is(displacement == void) || is(typeof(displacement) : int))
		&& (is(scale == void) || (scale > 0 && scale <= 8 && uint(scale).isPowerOfTwo))
	)
	{
		pragma(inline, true)
		mixin(accessType == "read" ? "T" : "void") access (string accessType) (
			scope AliasSeq!(void*)[0 .. purely] makeWeaklyPure,
			AliasSeq!(T)[0 .. mixin(accessType == "write" ? "1" : "0")] value,
			AliasSeq!(int)[0 .. is(displacement == void)] runtimeDisplacement,
			AliasSeq!(uint)[0 .. !is(scale == void)] index
		) @system
		if (accessType == "read" || accessType == "write")
		{
			enum bool writing = mixin(accessType == "write" ? "true" : "false");

			version (DigitalMars)
			{
				/+ Writing this as naked assembly was a miscalculation. +/

				static if (!purely)
				{
					asm @safe nothrow @nogc
					{}
				}

				asm @safe pure nothrow @nogc
				{
					naked;
				}

				enum string ptr = x86Ptr[T.sizeof];

				/+ DMD can into optimising compiler! +/

				version (X86)
				{
					enum byte valueStackSize = writing ? (T.sizeof == 8 ? 8 : 4) : 0;
					enum byte valueStackOffset = 4 + 4 * (is(displacement == void) && !is(scale == void));

					static if (is(displacement == void) && !is(scale == void))
					{
						enum byte runtimeDisplacementOffset = 4;

						asm @safe pure nothrow @nogc
						{
							mov EDX, [ESP + runtimeDisplacementOffset];
						}

						enum string displacementValue = "EDX";
					}
					else
					{
						enum string displacementValue = is(displacement == void) ? "EAX" : "displacement";
					}

					static if (is(scale == void))
					{
						enum string sib = "";
					}
					else
					{
						enum string sib = "EAX * 0x" ~ scale.asHex ~ " + ";
					}

					enum string memory = "[" ~ sib ~ displacementValue ~ "]";

					static if (T.sizeof <= 4)
					{
						enum size = T.sizeof.integralLog2;

						static if (writing)
						{
							static if (!is(displacement == void) && is(scale == void) && !is(Unqual!T == float))
							{
								mixin("asm pure nothrow @nogc {mov FS:", memory, ", ", x86Reg[0][size], ";}");
							}
							else
							{
								asm @safe pure nothrow @nogc
								{
									mov ECX, [ESP + valueStackOffset];
								}

								mixin("asm pure nothrow @nogc {mov FS:", memory, ", ", x86Reg[1][size], ";}");
							}
						}
						else
						{
							static if (T.sizeof <= 2)
							{
								static if (displacementValue == "EAX")
								{
									enum string readFrom = "[" ~ sib ~ "EDX" ~ "]";

									asm @safe pure nothrow @nogc
									{
										mov EDX, EAX;
									}
								}
								else static if (!is(scale == void))
								{
									enum string readFrom = "[" ~ "ECX * 0x" ~ scale.asHex ~ " + " ~ displacementValue ~ "]";

									asm @safe pure nothrow @nogc
									{
										mov ECX, EAX;
									}
								}
								else
								{
									enum string readFrom = memory;
								}

								asm @safe pure nothrow @nogc
								{
									xor EAX, EAX;
								}
							}
							else
							{
								enum string readFrom = memory;
							}

							mixin("asm pure nothrow @nogc {mov ", x86Reg[0][size], ", FS:", readFrom, ";}");
						}
					}
					else
					{
						static if (is(displacement == void) || (writing && !is(scale == void)))
						{
							mixin("asm pure nothrow @nogc {lea ECX, ", memory, ";}");
						}
						else
						{
							enum int highDisplacement = displacement + 4;
						}

						static if (writing)
						{
							enum byte valueStackHighOffset = valueStackOffset + 4;

							asm @safe pure nothrow @nogc
							{
								mov EAX, [ESP + valueStackOffset];
								mov EDX, [ESP + valueStackHighOffset];
							}

							static if (is(displacement == void) || !is(scale == void))
							{
								asm @safe pure nothrow @nogc
								{
									mov FS:[ECX], EAX;
									mov FS:[ECX + 4], EDX;
								}
							}
							else
							{
								mixin(
									"asm pure nothrow @nogc",
									"{",
									"	mov FS:", memory, ", EAX;",
									"	mov FS:[", sib, "highDisplacement], EDX;",
									"}"
								);
							}
						}
						else
						{
							static if (is(displacement == void))
							{
								asm @safe pure nothrow @nogc
								{
									mov EAX, FS:[ECX];
									mov EDX, FS:[ECX + 4];
								}
							}
							else
							{
								mixin(
									"asm pure nothrow @nogc",
									"{",
									"	mov EDX, FS:[", sib, "highDisplacement];",
									"	mov EAX, FS:", memory, ";",
									"}"
								);
							}
						}
					}

					enum ushort argumentStackSize = (
						  4 * (is(displacement == void) && !is(scale == void))
						+ (
							  T.sizeof == 8
							? 8 * writing
							: 4 * (writing && (is(displacement == void) || !is(scale == void)))
						)
						+ 4 * (purely && (writing || is(displacement == void) || !is(scale == void)))
					);

					mixin("asm @safe pure nothrow @nogc {ret ", argumentStackSize == 0 ? "" : "argumentStackSize", ";}");
				}
				else version (X86_64)
				{
					enum size = T.sizeof.integralLog2;
					enum intArg = x64IntArg[__traits(parameters).length];
					enum floatArg = x64FloatArg[__traits(parameters).length];

					static if (writing)
					{
						enum ubyte valueIndex = purely;
						enum ubyte runtimeDisplacementIndex = purely + 1;
						enum ubyte indexIndex = purely + 1 + is(displacement == void);
					}
					else
					{
						enum ubyte runtimeDisplacementIndex = purely;
						enum ubyte indexIndex = purely + is(displacement == void);
					}

					static if (is(displacement == void))
					{
						enum string displacementValue = x86Reg[intArg[runtimeDisplacementIndex]][2];
					}
					else
					{
						enum string displacementValue = "R10D";
					}

					static if (is(scale == void))
					{
						enum string sib = "";
					}
					else
					{
						enum string sib = x86Reg[intArg[indexIndex]][2] ~ " * 0x" ~ scale.asHex ~ " + ";
					}

					enum string memory = "[" ~ sib ~ displacementValue ~ "]";

					static if (!is(displacement == void))
					{
						asm @safe pure nothrow @nogc
						{
							mov R10D, displacement;
						}
					}

					static if (writing)
					{
						static if (is(Unqual!T == float))
						{
							mixin("asm pure nothrow @nogc {movss GS:", memory, ", ", x86MMReg[floatArg[valueIndex]][1], ";}");
						}
						else static if (is(Unqual!T == double))
						{
							mixin("asm pure nothrow @nogc {movsd GS:", memory, ", ", x86MMReg[floatArg[valueIndex]][1], ";}");
						}
						else
						{
							mixin("asm pure nothrow @nogc {mov GS:", memory, ", ", x86Reg[intArg[valueIndex]][size], ";}");
						}
					}
					else
					{
						static if (is(Unqual!T == float))
						{
							mixin("asm pure nothrow @nogc {movss XMM0, GS:", memory, ";}");
						}
						else static if (is(Unqual!T == double))
						{
							mixin("asm pure nothrow @nogc {movsd XMM0, GS:", memory, ";}");
						}
						else
						{
							mixin("asm pure nothrow @nogc {mov ", x86Reg[0][size], ", GS:", memory, ";}");
						}
					}

					asm @safe pure nothrow @nogc
					{
						ret;
					}
				}
			}
			else version (LDC)
			{
				alias ir = mixin(purely ? "__ir_pure" : "__ir");

				int address = mixin(calculateTIBDisplacementAddress);

				static if (x86X)
				{
					     version (X86) enum string addressSpace = "addrspace(257)";
					else version (X86_64) enum string addressSpace = "addrspace(256)";

					enum string type = llvmIRIntsBySizeOf[T.sizeof];
					enum string segmentPointer = llvmIRPtr!(type, addressSpace);

					static if (writing)
					{
						union Data
						{
							T asValue;
							UIntsFittingSizeOf[T.sizeof] asInteger;
						}

						ir!(
							"%address = inttoptr " ~ llvmIRIntsBySizeOf[int.sizeof] ~ " %1 to " ~ segmentPointer ~ ";
							 store " ~ type ~ "%0, " ~ segmentPointer ~ " %address;",
							void,
							UIntsFittingSizeOf[T.sizeof],
							int
						)(Data(value[0]).asInteger, address);
					}
					else
					{
						union Data
						{
							UIntsFittingSizeOf[T.sizeof] asInteger;
							T asValue;
						}

						return Data(
							ir!(
								"%address = inttoptr " ~ llvmIRIntsBySizeOf[int.sizeof] ~ " %0 to " ~ segmentPointer ~ ";
								 %data = load " ~ type ~ ", " ~ segmentPointer ~ " %address;
								 ret " ~ type ~ " %data;",
								UIntsFittingSizeOf[T.sizeof],
								int
							)(address)
						).asValue;
					}
				}
				else static if (ARM)
				{
					auto pointer = mixin(makeTIBDisplacementPointer!(q{T*}, q{addressOfTIB!purely(makeWeaklyPure)}));

					static if (writing)
					{
						*pointer = value[0];
					}
					else
					{
						return *pointer;
					}
				}
			}
		}
	}


	@trusted nothrow @nogc unittest
	{
		enum byte lastErrorOffset = pointerAndByteOffset(13, 0);
		enum byte criticalSectionCountOffset = lastErrorOffset + 4;

		static void test (Flag!"purely" purely, Flag!"asFloat" asFloats) ()
		{
			static if (purely)
			{
				auto p = weaklyPureTIBAccess;
			}
			else
			{
				AliasSeq!() p;
			}

			static if (asFloats)
			{
				alias UInt = float;
				alias ULong = double;
			}
			else
			{
				alias UInt = uint;
				alias ULong = ulong;
			}

			union D
			{
				uint asInt;
				float asFloat;

				mixin("alias v = ", asFloats ? "asFloat" : "asInt", ";");
			}

			union Q
			{
				ulong asInt;
				double asFloat;

				mixin("alias v = ", asFloats ? "asFloat" : "asInt", ";");
			}

			static bool eq (T) (T a, T b)
			{
				static if (is(Unqual!T == float) || is(Unqual!T == double))
				{
					return a is b;
				}
				else
				{
					return a == b;
				}
			}

			SetLastError(0);

			auto originalCriticalSectionCountOffset = readFromTIB!(uint, criticalSectionCountOffset);

			assert(readFromTIB!(uint, lastErrorOffset, void, purely)(p) == 0);

			writeToTIB!(UInt, lastErrorOffset, void, purely)(p, D(0xFFFFFFFF).v);

			assert(GetLastError == 0xFFFFFFFF);
			assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0xFFFFFFFF).v));

			writeToTIB!(ubyte, lastErrorOffset, void, purely)(p, 0xAA);
			assert(GetLastError == 0xFFFFFFAA);
			assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0xFFFFFFAA).v));
			assert(readFromTIB!(ubyte, lastErrorOffset, void, purely)(p) == 0xAA);

			writeToTIB!(ushort, lastErrorOffset, void, purely)(p, 0xAABB);
			assert(GetLastError == 0xFFFFAABB);
			assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0xFFFFAABB).v));
			assert(readFromTIB!(ushort, lastErrorOffset, void, purely)(p) == 0xAABB);

			void innerTest ()
			{
				writeToTIB!(ubyte, lastErrorOffset, 1, purely)(p, 0x11, 0);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0xFFFFAA11).v));

				writeToTIB!(ubyte, lastErrorOffset, 1, purely)(p, 0x22, 1);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0xFFFF2211).v));
				writeToTIB!(ubyte, lastErrorOffset, 1, purely)(p, 0x33, 2);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0xFF332211).v));

				writeToTIB!(ushort, lastErrorOffset, 2, purely)(p, 0x4455, 1);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0x44552211).v));

				assert(readFromTIB!(ubyte, void, void, purely)(p, lastErrorOffset) == 0x11);
				assert(readFromTIB!(ushort, void, void, purely)(p, lastErrorOffset) == 0x2211);
				assert(eq(readFromTIB!(UInt, void, void, purely)(p, lastErrorOffset), D(0x44552211).v));

				assert(readFromTIB!(ubyte, void, 1, purely)(p, lastErrorOffset, 0) == 0x11);
				assert(readFromTIB!(ubyte, void, 1, purely)(p, lastErrorOffset, 1) == 0x22);
				assert(readFromTIB!(ubyte, void, 1, purely)(p, lastErrorOffset, 2) == 0x55);
				assert(readFromTIB!(ubyte, void, 2, purely)(p, lastErrorOffset, 1) == 0x55);
				assert(readFromTIB!(ushort, void, 2, purely)(p, lastErrorOffset, 1) == 0x4455);
				assert(eq(readFromTIB!(UInt, void, 8, purely)(p, lastErrorOffset, 0), D(0x44552211).v));

				assert(readFromTIB!(ubyte, lastErrorOffset, 1, purely)(p, 0) == 0x11);
				assert(readFromTIB!(ubyte, lastErrorOffset, 1, purely)(p, 1) == 0x22);
				assert(readFromTIB!(ubyte, lastErrorOffset, 1, purely)(p, 2) == 0x55);
				assert(readFromTIB!(ubyte, lastErrorOffset, 2, purely)(p, 1) == 0x55);
				assert(readFromTIB!(ushort, lastErrorOffset, 2, purely)(p, 1) == 0x4455);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, 8, purely)(p, 0), D(0x44552211).v));

				writeToTIB!(ushort, void, void, purely)(p, 0xCCDD, lastErrorOffset);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0x4455CCDD).v));

				writeToTIB!(byte, void, void, purely)(p, cast(byte) 0xEE, lastErrorOffset + 2);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0x44EECCDD).v));

				writeToTIB!(UInt, void, void, purely)(p, D(0x22446688).v, lastErrorOffset);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0x22446688).v));

				writeToTIB!(ubyte, void, 1, purely)(p, 0xAA, lastErrorOffset, 0);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0x224466AA).v));

				writeToTIB!(ubyte, void, 1, purely)(p, 0xBB, lastErrorOffset, 1);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0x2244BBAA).v));

				writeToTIB!(ubyte, void, 2, purely)(p, 0xCC, lastErrorOffset, 1);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0x22CCBBAA).v));

				writeToTIB!(ushort, void, 2, purely)(p, 0xEEDD, lastErrorOffset, 1);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0xEEDDBBAA).v));

				writeToTIB!(UInt, void, 4, purely)(p, D(0xBBAAEEDD).v, lastErrorOffset, 0);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0xBBAAEEDD).v));

				writeToTIB!(ubyte, lastErrorOffset, 1, purely)(p, 0x99, 0);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0xBBAAEE99).v));

				writeToTIB!(ubyte, lastErrorOffset, 1, purely)(p, 0x22, 1);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0xBBAA2299).v));

				writeToTIB!(ubyte, lastErrorOffset, 2, purely)(p, 0x33, 1);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0xBB332299).v));

				writeToTIB!(ushort, lastErrorOffset, 2, purely)(p, 0x1234, 1);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0x12342299).v));

				writeToTIB!(UInt, lastErrorOffset, 4, purely)(p, D(0x01010203).v, 0);
				assert(eq(readFromTIB!(UInt, lastErrorOffset, void, purely)(p), D(0x01010203).v));

				writeToTIB!(UInt, criticalSectionCountOffset, void, purely)(p, D(0xFFEEDDCC).v);
				assert(eq(readFromTIB!(UInt, criticalSectionCountOffset, void, purely)(p), D(0xFFEEDDCC).v));

				assert(eq(readFromTIB!(ULong, lastErrorOffset, void, purely)(p), Q(0xFFEEDDCC_01010203).v));
				assert(eq(readFromTIB!(ULong, lastErrorOffset - 8, 4, purely)(p, 2), Q(0xFFEEDDCC_01010203).v));
				assert(eq(readFromTIB!(ULong, void, 4, purely)(p, lastErrorOffset - 8, 2), Q(0xFFEEDDCC_01010203).v));
				assert(eq(readFromTIB!(ULong, void, void, purely)(p, lastErrorOffset), Q(0xFFEEDDCC_01010203).v));

				writeToTIB!(ULong, lastErrorOffset, void, purely)(p, Q(0x11223344_55667788).v);
				assert(eq(readFromTIB!(UInt, lastErrorOffset + 4, void, purely)(p), D(0x11223344).v));
				assert(eq(readFromTIB!(UInt, lastErrorOffset + 0, void, purely)(p), D(0x55667788).v));

				writeToTIB!(ULong, lastErrorOffset - 8, 4, purely)(p, Q(0x33445566_778899AA).v, 2);
				assert(eq(readFromTIB!(UInt, lastErrorOffset + 4, void, purely)(p), D(0x33445566).v));
				assert(eq(readFromTIB!(UInt, lastErrorOffset + 0, void, purely)(p), D(0x778899AA).v));

				writeToTIB!(ULong, void, 4, purely)(p, Q(0xBBCCDDEE_FF001122).v, lastErrorOffset - 8, 2);
				assert(eq(readFromTIB!(UInt, lastErrorOffset + 4, void, purely)(p), D(0xBBCCDDEE).v));
				assert(eq(readFromTIB!(UInt, lastErrorOffset + 0, void, purely)(p), D(0xFF001122).v));

				writeToTIB!(ULong, void, void, purely)(p, Q(0x446688AA_CCEE1133).v, lastErrorOffset);
				assert(eq(readFromTIB!(UInt, lastErrorOffset + 4, void, purely)(p), D(0x446688AA).v));
				assert(eq(readFromTIB!(UInt, lastErrorOffset + 0, void, purely)(p), D(0xCCEE1133).v));

				uint asInt = 0xCCEE1133;
				float asFloat = *cast(const(float*)) &asInt;

				assert(readFromTIB!(float, lastErrorOffset, void, purely)(p) == asFloat);
			}

			static if (purely)
			{
				(() pure => innerTest)();
			}
			else
			{
				innerTest;
			}

			writeToTIB!(uint, criticalSectionCountOffset, void, purely)(p, originalCriticalSectionCountOffset);
		}

		test!(No.purely, No.asFloat);
		test!(No.purely, Yes.asFloat);

		test!(Yes.purely, No.asFloat);
		test!(Yes.purely, Yes.asFloat);
	}


	void* addressOfTIB () @trusted nothrow @nogc
	{
		return addressOfTIB!();
	}


	void* addressOfTIB (Flag!"purely" purely = No.purely) (
		scope AliasSlice!(0, purely, void*) makeWeaklyPure
	) @trusted nothrow @nogc
	{
		static if (x86X)
		{
			return readFromTIB!(void*, pointerAndByteOffset(6, 0), void, purely)(makeWeaklyPure);
		}
		else static if (ARM)
		{
			alias ir = mixin(purely ? "__ir_pure" : "__ir");

			version (AArch64)
			{
				return ir!(
					`%address = call i8* asm "", "={X18}"()
					 ret i8* %address`,
					void*
				);
			}
			else
			{
				return ir!(
					`%address = call i8* asm "mrc p15, #0, $0, c13, c0, #2", "=r"()
					 ret i8* %address`,
					void*
				);
			}
		}
	}


	version (DigitalMars)
	{
		private enum string[4][16] x86Reg = [
			["AL", "AX", "EAX", "RAX"],
			["CL", "CX", "ECX", "RCX"],
			["DL", "DX", "EDX", "RDX"],
			["BL", "BX", "EBX", "RBX"],
			["SPL", "SP", "ESP", "RSP"],
			["BPL", "BP", "EBP", "RBP"],
			["SIL", "SI", "ESI", "RSI"],
			["DIL", "DI", "EDI", "RDI"],
			["R8B", "R8W", "R8D", "R8"],
			["R9B", "R9W", "R9D", "R9"],
			["R10B", "R10W", "R10D", "R10"],
			["R11B", "R11W", "R11D", "R11"],
			["R12B", "R12W", "R12D", "R12"],
			["R13B", "R13W", "R13D", "R13"],
			["R14B", "R14W", "R14D", "R14"],
			["R15B", "R15W", "R15D", "R15"]
		];

		private enum string[4][32] x86MMReg = [
			["MM0", "XMM0", "YMM0", "ZMM0"],
			["MM1", "XMM1", "YMM1", "ZMM1"],
			["MM2", "XMM2", "YMM2", "ZMM2"],
			["MM3", "XMM3", "YMM3", "ZMM3"],
			["MM4", "XMM4", "YMM4", "ZMM4"],
			["MM5", "XMM5", "YMM5", "ZMM5"],
			["MM6", "XMM6", "YMM6", "ZMM6"],
			["MM7", "XMM7", "YMM7", "ZMM7"],
			[null, "XMM8", "YMM8", "ZMM8"],
			[null, "XMM9", "YMM9", "ZMM9"],
			[null, "XMM10", "YMM10", "ZMM10"],
			[null, "XMM11", "YMM11", "ZMM11"],
			[null, "XMM12", "YMM12", "ZMM12"],
			[null, "XMM13", "YMM13", "ZMM13"],
			[null, "XMM14", "YMM14", "ZMM14"],
			[null, "XMM15", "YMM15", "ZMM15"],
			[null, "XMM16", "YMM16", "ZMM16"],
			[null, "XMM17", "YMM17", "ZMM17"],
			[null, "XMM18", "YMM18", "ZMM18"],
			[null, "XMM19", "YMM19", "ZMM19"],
			[null, "XMM20", "YMM20", "ZMM20"],
			[null, "XMM21", "YMM21", "ZMM21"],
			[null, "XMM22", "YMM22", "ZMM22"],
			[null, "XMM23", "YMM23", "ZMM23"],
			[null, "XMM24", "YMM24", "ZMM24"],
			[null, "XMM25", "YMM25", "ZMM25"],
			[null, "XMM26", "YMM26", "ZMM26"],
			[null, "XMM27", "YMM27", "ZMM27"],
			[null, "XMM28", "YMM28", "ZMM28"],
			[null, "XMM29", "YMM29", "ZMM29"],
			[null, "XMM30", "YMM30", "ZMM30"],
			[null, "XMM31", "YMM31", "ZMM31"]
		];

		version (X86_64)
		{
			version (Windows)
			{
				private enum ubyte[][5] x64IntArg = [
					[],
					[1],
					[2, 1],
					[8, 2, 1],
					[9, 8, 2, 1]
				];

				private enum ubyte[][5] x64FloatArg = [
					[],
					[0],
					[1, 0],
					[2, 1, 0],
					[3, 2, 1, 0]
				];
			}
		}

		private enum string[] x86Ptr = [null, "ubyte ptr", "word ptr", null, "dword ptr", null, null, null, "qword ptr"];
	}
}

