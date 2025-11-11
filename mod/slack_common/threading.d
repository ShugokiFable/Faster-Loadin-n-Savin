
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.threading;

import core.atomic : atomicFetchAdd, atomicLoad, atomicStore, MemoryOrder;

import slack_common.bindings;
import slack_common.byte_sizes;
import slack_common.dynamically_linked;
import slack_common.integers;
import slack_common.timing;

import std.traits : Unqual;


pragma(inline, true)
NTSTATUS makeThread (
	scope HANDLE* threadHandle,
	PUSER_THREAD_START_ROUTINE threadProcedure,
	void* context = null,
	uint flags = 0,
	size_t stackCommit = 16.KB,
	size_t stackReserve = 64.KB
) @trusted nothrow @nogc
{
	NTSTATUS error = NtCreateThreadEx(
		threadHandle,
		THREAD_ALL_ACCESS,
		null,
		thisProcess,
		threadProcedure,
		context,
		flags,
		0,
		stackCommit,
		stackReserve,
		null
	);

	assert(error ^ (*threadHandle != null));

	return error;
}


pragma(inline, true)
void waitFor (SystemTimeValue time) @trusted nothrow @nogc
{
	version (Windows)
	{
		NtDelayExecution(false, cast(LARGE_INTEGER*) &time.value);
	}
	else
	{
		static assert(false);
	}
}


pragma(inline, true)
uint waitVia (T, U) (scope T* address, scope auto ref U expecting) @trusted
if (T.sizeof.isPowerOfTwo && T.alignof >= T.sizeof && is(Unqual!T == Unqual!U))
{
	/+ We use two type-parameters so that T and U can differ in constness. +/

	static assert(T.sizeof <= 8);

	return linked.RtlWaitOnAddress(
		cast(const(void)*) address,
		cast(const(void)*) &expecting,
		T.sizeof,
		null
	);
}


pragma(inline, true)
auto wakeOneThreadVia (T) (scope T* address) @trusted
if (T.sizeof.isPowerOfTwo && T.alignof >= T.sizeof)
{
	static assert(T.sizeof <= 8);

	linked.RtlWakeAddressSingle(cast(const(void)*) address);

	return true;
}


pragma(inline, true)
auto wakeAllThreadsVia (T) (scope T* address) @trusted
if (T.sizeof.isPowerOfTwo && T.alignof >= T.sizeof)
{
	static assert(T.sizeof <= 8);

	linked.RtlWakeAddressAll(cast(const(void)*) address);

	return true;
}


struct ThreadBarrier (bool compact = size_t.sizeof < 8)
{
	static if (compact)
	{
		alias Int = ushort;
	align(4)
		Int fingerprint;
		Int ramCount;
	}
	else
	{
		alias Int = uint;
	align(8)
		Int fingerprint;
		Int ramCount;
	}

	/+ Returns whether this ram was the impact that broke the barrier or not. +/
	pragma(inline, true)
	bool ram (uint threshold) scope @safe nothrow @nogc
	{
		if (this.twoStageRam(threshold))
		{
			this.finishingBlow;
			return true;
		}
		else
		{
			return false;
		}
	}

	/+ Returns whether this ram is the impact to break the barrier or not. +/
	bool twoStageRam (uint threshold) scope @safe nothrow @nogc
	{
		auto inkedFingerprint = this.fingerprint.atomicLoad!(MemoryOrder.acq);
		auto threadsAtBarrierCount = this.ramCount.atomicFetchAdd!(MemoryOrder.acq_rel)(1);

		if (threadsAtBarrierCount == threshold - 1)
		{
			return true;
		}
		else
		{
		wait:
			if (this.fingerprint.atomicLoad!(MemoryOrder.acq) == inkedFingerprint)
			{
				waitVia(&this.fingerprint, inkedFingerprint);
				goto wait;
			}

			return false;
		}
	}

	/+ Used to finalise a two-stage ram. +/
	void finishingBlow () scope @safe nothrow @nogc
	{
		this.ramCount.atomicStore!(MemoryOrder.rel)(Int(0));
		this.fingerprint.atomicFetchAdd!(MemoryOrder.acq_rel)(1);

		wakeAllThreadsVia(&this.fingerprint);
	}
}

