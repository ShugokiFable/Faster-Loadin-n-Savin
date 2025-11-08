
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.algorithms;

import slack_common.integers;
import slack_common.memory;
import slack_common.simd;
import slack_common.versions;


pragma(inline, true)
auto lesserOf (Values...) (Values values)
{
	static if (Values.length == 2)
	{
		return values[0] <= values[1] ? values[0] : values[1];
	}
	else static if (Values.length > 2)
	{
		return lesserOf(values[0], lesserOf(values[1 .. $]));
	}
	else static if (Values.length == 1)
	{
		return values[0];
	}
}


pragma(inline, true)
auto greaterOf (Values...) (Values values)
{
	static if (Values.length == 2)
	{
		return values[0] >= values[1] ? values[0] : values[1];
	}
	else static if (Values.length > 2)
	{
		return greaterOf(values[0], greaterOf(values[1 .. $]));
	}
	else static if (Values.length == 1)
	{
		return values[0];
	}
}


T* findSentinel (alias sentinel, size_t alignment = 0, T) (return scope T* data)
if (is(typeof(sentinel) : T) && (alignment == 0 || alignment.isPowerOfTwo))
in
{
	static if (alignment > 0)
	{
		assert(__ctfe || (cast(size_t) data & (alignment - 1)) == 0);
	}
}
do
{
	/+ This implementation optimises for code size, with the logic being that
	   most sentinel-terminated arrays are short, and thus the overhead of a function call
	   outweighs the benefit of a longer implementation; thus we keep the implementation short,
	   so that it's more amenable to inlining. +/

	static if (x86X)
	{
		enum size_t byteWidth = 16;
		alias movmsk = __builtin_ia32_pmovmskb128;
		alias Mask = ushort;
	}
	else
	{
		alias Mask = void;
	}

	static if (is(Mask == void))
	{
		enum bool usingSIMD = false;
	}
	else
	{
		enum bool usingSIMD = T.sizeof <= 8 && byteWidth % T.sizeof == 0 && byteWidth / T.sizeof >= 4;
	}

	static if (!usingSIMD)
	{
	next:
		if (*data is sentinel)
		{
			return data;
		}

		++data;

		goto next;
	}
	else
	{
		enum size_t chunkScale = T.sizeof.leastSetBitIndex >= 3 ? 3 : T.sizeof.leastSetBitIndex;
		enum size_t chunkSize = size_t(1) << chunkScale;

		enum size_t chunksInVector = byteWidth >>> chunkScale;

		alias Chunk = IntsFittingSizeOf[chunkSize];

		alias V = __vector(Chunk[chunksInVector]);
		alias ByteV = __vector(byte[byteWidth]);

		enum size_t pageMask = minimumPageSize - 1;
		enum size_t vectorMask = byteWidth - 1;
		enum size_t pageThreshold = pageMask - vectorMask;

		V sentinelVector = cast(Chunk) sentinel;
		Chunk* chunk = cast(Chunk*) data;
		size_t offsetInPage;
		size_t underread;
		size_t bytesLeftInPage;
	nextChunk:
		offsetInPage = cast(size_t) chunk & pageMask;
		bytesLeftInPage = pageMask - offsetInPage;

		underread = offsetInPage < pageThreshold ? 0 : (vectorMask ^ bytesLeftInPage);

		chunk = cast(Chunk*) (cast(void*) chunk - underread);

		V vector = loadVector!(V, alignment)(chunk);
		V equality = vector == sentinelVector;
		Mask mask = cast(Mask) movmsk(cast(ByteV) equality);

		mask >>= underread;

		uint bix = mask.leastSetBitIndex!(No.definedForZero);

		if (mask != 0)
		{
			return cast(T*) cast(Chunk*) (cast(void*) chunk + bix + underread);
		}

		chunk = cast(Chunk*) (cast(void*) chunk + byteWidth);

		goto nextChunk;
	}
}


pure nothrow @nogc unittest
{
	align(minimumPageSize) ubyte[minimumPageSize] page;
	assert((cast(size_t) page.ptr & (minimumPageSize - 1)) == 0);

	(cast(char[]) page)[0 .. 72] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-\0\0\0\0\0\0\0\0";

	assert((cast( char*) page.ptr).findSentinel!'\0' == cast( char*) &page[64]);
	assert((cast(wchar*) page.ptr).findSentinel!'\0' == cast(wchar*) &page[64]);
	assert((cast(dchar*) page.ptr).findSentinel!'\0' == cast(dchar*) &page[64]);
	assert((cast(ulong*) page.ptr).findSentinel!'\0' == cast(ulong*) &page[64]);

	assert((cast( char*) &page[64]).findSentinel!'\0' == cast( char*) &page[64]);
	assert((cast(wchar*) &page[64]).findSentinel!'\0' == cast(wchar*) &page[64]);
	assert((cast(dchar*) &page[64]).findSentinel!'\0' == cast(dchar*) &page[64]);
	assert((cast(ulong*) &page[64]).findSentinel!'\0' == cast(ulong*) &page[64]);

	(cast(char[]) page)[minimumPageSize - 8 .. minimumPageSize] = "\r\r\r\r\r\r\r\0";
	assert((cast( char*) &page[minimumPageSize - 8]).findSentinel!'\0' == cast( char*) &page[minimumPageSize - 1]);
	(cast(char[]) page)[minimumPageSize - 8 .. minimumPageSize] = "\r\r\r\r\r\r\0\0";
	assert((cast(wchar*) &page[minimumPageSize - 8]).findSentinel!'\0' == cast(wchar*) &page[minimumPageSize - 2]);
	(cast(char[]) page)[minimumPageSize - 8 .. minimumPageSize] = "\r\r\r\r\0\0\0\0";
	assert((cast(dchar*) &page[minimumPageSize - 8]).findSentinel!'\0' == cast(dchar*) &page[minimumPageSize - 4]);
	(cast(char[]) page)[minimumPageSize - 8 .. minimumPageSize] = "\0\0\0\0\0\0\0\0";
	assert((cast(ulong*) &page[minimumPageSize - 8]).findSentinel!'\0' == cast(ulong*) &page[minimumPageSize - 8]);

	(cast(char[]) page)[32 .. 48] = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";

	assert((cast(void[]*) page.ptr).findSentinel!null == cast(void[]*) &page[32]);
}

