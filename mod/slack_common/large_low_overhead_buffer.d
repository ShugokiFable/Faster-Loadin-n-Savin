
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.large_low_overhead_buffer;

import slack_common.bindings;
import slack_common.memory;


struct LargeAndLowOverheadSequentialBuffer
{
	ubyte* base;
	ubyte* commit;
	ubyte* tail;

	pragma(inline, true)
	inout(ubyte)* unguardedTail () inout return scope @trusted pure nothrow @nogc
	{
		return this.tail + minimumPageSize;
	}

	pragma(inline, true)
	bool encloses (scope const(void)* address) const scope @trusted pure nothrow @nogc
	{
		return (address >= this.base) & (address < this.unguardedTail);
	}

	NTSTATUS expandCommitTo (size_t size) scope @trusted nothrow @nogc
	{
		ubyte* base = this.base;
		size_t limit = this.tail - base;

		size = size <= limit ? size : limit;

		NTSTATUS error = NtAllocateVirtualMemory(thisProcess, cast(void**) &base, 0, &size, MEM_COMMIT, PAGE_READWRITE);

		if (error)
		{
			return error;
		}

		this.commit = base + size;

		return 0;
	}

	NTSTATUS expandCommit () scope @trusted nothrow @nogc
	{
		size_t size = this.commit - base;
		size <<= 1;
		return this.expandCommitTo(size);
	}

	void free () scope nothrow @nogc
	{
		size_t freeAll = 0;
		NtFreeVirtualMemory(thisProcess, cast(void**) &base, &freeAll, MEM_RELEASE);
	}
}


NTSTATUS makeLargeAndLowOverheadSequentialBuffer (
	scope LargeAndLowOverheadSequentialBuffer* buffer,
	size_t reservation,
	size_t commit,
	scope MEM_EXTENDED_PARAMETER[] extendedParameters
) @trusted nothrow @nogc
in (reservation >= minimumPageSize)
in (commit <= reservation)
in (commit <= reservation - minimumPageSize)
in (extendedParameters.length < uint.max)
{
	buffer.base = null;

	size_t size = reservation;

	NTSTATUS error = NtAllocateVirtualMemoryEx(
		thisProcess,
		cast(void**) &buffer.base,
		&size,
		MEM_RESERVE,
		PAGE_READWRITE,
		extendedParameters.ptr,
		cast(uint) extendedParameters.length
	);

	if (error)
	{
		return error;
	}

	buffer.tail = buffer.base + size - minimumPageSize;

	size = commit;

	error = NtAllocateVirtualMemory(thisProcess, cast(void**) &buffer.base, 0, &size, MEM_COMMIT, PAGE_READWRITE);

	if (error)
	{
		size = 0;
		NtFreeVirtualMemory(thisProcess, cast(void**) &buffer.base, &size, MEM_RELEASE);
		return error;
	}

	buffer.commit = buffer.base + size;

	return 0;
}


struct LargeAndLowOverheadPartitionedBuffer
{
	ubyte* base;
	ubyte* tail;
	uint partitionBixponent;

	pragma(inline, true)
	size_t partitionOf (scope const(ubyte)* address) const scope @trusted pure nothrow @nogc
	{
		return (address - this.base) >>> this.partitionBixponent;
	}

	pragma(inline, true)
	size_t partitionSize () const @property scope @trusted pure nothrow @nogc
	{
		return this.unguardedPartitionSize - minimumPageSize;
	}

	pragma(inline, true)
	size_t unguardedPartitionSize () const @property scope @trusted pure nothrow @nogc
	{
		return size_t(1) << this.partitionBixponent;
	}

	pragma(inline, true)
	inout(ubyte)* baseOf (size_t partition) inout return scope @trusted pure nothrow @nogc
	{
		return this.base + (partition << this.partitionBixponent);
	}

	pragma(inline, true)
	inout(ubyte)* unguardedTailOf (size_t partition) inout return scope @trusted pure nothrow @nogc
	{
		return this.baseOf(partition + 1);
	}

	pragma(inline, true)
	inout(ubyte)* tailOf (size_t partition) inout return scope @trusted pure nothrow @nogc
	{
		return this.unguardedTailOf(partition) - minimumPageSize;
	}

	pragma(inline, true)
	bool encloses (scope const(void)* address) const scope @trusted pure nothrow @nogc
	{
		return (address >= this.base) & (address < this.tail);
	}

	void free () scope nothrow @nogc
	{
		size_t freeAll = 0;
		NtFreeVirtualMemory(thisProcess, cast(void**) &base, &freeAll, MEM_RELEASE);
	}
}


NTSTATUS makeLargeAndLowOverheadPartitionedBuffer (
	scope LargeAndLowOverheadPartitionedBuffer* buffer,
	uint partitionBixponent,
	size_t partitionCount,
	scope MEM_EXTENDED_PARAMETER[] extendedParameters
) @trusted nothrow @nogc
in (partitionBixponent >= 12)
in (partitionCount <= size_t.max >>> partitionBixponent)
in (extendedParameters.length < uint.max)
{
	buffer.partitionBixponent = partitionBixponent;
	buffer.base = null;

	size_t size = partitionCount << partitionBixponent;

	NTSTATUS error = NtAllocateVirtualMemoryEx(
		thisProcess,
		cast(void**) &buffer.base,
		&size,
		MEM_RESERVE,
		PAGE_READWRITE,
		extendedParameters.ptr,
		cast(uint) extendedParameters.length
	);

	if (error)
	{
		return error;
	}

	buffer.tail = buffer.base + size;

	return 0;
}

