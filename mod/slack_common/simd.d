
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.simd;

import slack_common.versions;

import std.traits : Unqual;

public import core.simd;

static if (LDC)
{
	static if (x86X)
	{
		public import ldc.gccbuiltins_x86;
	}
}
else static if (GDC)
{
	public import gcc.builtins;
}


V loadVector (V, size_t alignment = 0, E) (scope const(E)* address)
{
	if (__ctfe)
	{
		return *cast(const(V)*) address;
	}
	else
	{
		static if ((alignment != 0 ? alignment : E.alignof) >= V.alignof)
		{
			return *cast(const(V)*) address;
		}
		else
		{
			static if (LDC)
			{
				return loadUnaligned!V(cast(const(typeof(V.array[0]))*) address);
			}
			else
			{
				return loadUnaligned(cast(const(V)*) address);
			}
		}
	}
}


void storeVector (V, size_t alignment = 0, E) (scope E* address, V value)
if (is(Unqual!E == E))
{
	if (__ctfe)
	{
		*cast(Unqual!V*) address = value;
	}
	else
	{
		static if ((alignment != 0 ? alignment : E.alignof) >= V.alignof)
		{
			*cast(Unqual!V*) address = value;
		}
		else
		{
			static if (LDC)
			{
				storeUnaligned!V(value, cast(Unqual!(typeof(V.array[0]))*) address);
			}
			else
			{
				storeUnaligned(cast(Unqual!V*) address, value);
			}
		}
	}
}
