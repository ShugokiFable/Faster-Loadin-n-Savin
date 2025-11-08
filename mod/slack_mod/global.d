
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_mod.global;

import slack_common.algorithms;
import slack_common.bindings;
import slack_common.cpp;
import slack_common.user_interface;
import slack_mod.configuration;
import slack_mod.save_load;

import skse64.dll_plugins;
import skse64.serialisation;


__gshared GlobalState global;


struct GlobalState
{
	HMODULE dllModule;
	ulong performanceFrequency;
	double performanceFrequencyMillisecondMultiplier = 0;
	bool haveWarnedUserAboutNearlyReachingSaveFileSizeLimit;
	ResolvedAddresses addressOf;
	ConfigurationLongLived configuration;
	SaveLoadState saveLoad;
}


struct ResolvedAddresses
{
	SKSE64Provider* globalSKSE64Provider;
	SerialisationProvider* globalSerialisationProvider;
	std_string* skseCosaveSavePath;
	std_vector!SerialisationStateForPlugin* cosaveAwarePlugins;
	ubyte* skseInitialiseCall;
	ubyte* createSKSECosave;
	ubyte* restoreSKSECosave;
	ubyte* createSKSECosaveCall;
	ubyte* restoreSKSECosaveCall;
	extern(C) void function (scope const(char)* format, ...) nothrow @nogc skseConsolePrint;

	version (SLACKVerificationMode)
	{
		typeof(SerialisationProvider.beginRecord) skseSerialisationBeginRecord;
		typeof(SerialisationProvider.writeRecord) skseSerialisationWriteRecord;
		typeof(SerialisationProvider.writeRecordData) skseSerialisationWriteRecordData;
		typeof(SerialisationProvider.readNextRecordHeader) readNextRecordHeader;
		typeof(SerialisationProvider.readRecordData) readRecordData;
	}
}


extern(Windows)
int vectoredExceptionHandler () (scope EXCEPTION_POINTERS* exceptionInfo) @system nothrow @nogc
{
	const(EXCEPTION_RECORD)* record = exceptionInfo.ExceptionRecord;

	if (record.ExceptionCode != EXCEPTION_ACCESS_VIOLATION)
	{
		return EXCEPTION_CONTINUE_SEARCH;
	}

	alias Config = ConfigurationLongLived.Flags;

	const(void)* faultingAddress = cast(const(void)*) record.ExceptionInformation[1];
	uint error = void;

	if (global.configuration.flags & Config.accelerateSaving)
	{
		if (global.configuration.flags & Config.enableParallelSaving)
		{
			if (global.saveLoad.parallel.cosaveBuffer.encloses(faultingAddress))
			{
				size_t partition = global.saveLoad.parallel.cosaveBuffer.partitionOf(cast(const(ubyte)*) faultingAddress);
				ubyte commitBixponent = global.saveLoad.parallel.cosaveBufferCommitBixponent[partition];

				commitBixponent = greaterOf(commitBixponent, ubyte(18));

				if (commitBixponent >= global.saveLoad.parallel.cosaveBuffer.partitionBixponent)
				{
					reportErrorToUser("A partition of the parallel cosave buffer has exceeded its maximum size.\r\nTHE GAME IS NOT FULLY SAVED.");
					return EXCEPTION_CONTINUE_SEARCH;
				}

				++commitBixponent;

				ubyte* base = global.saveLoad.parallel.cosaveBuffer.baseOf(partition);
				size_t size = size_t(1) << commitBixponent;

				error = NtAllocateVirtualMemory(thisProcess, cast(void**) &base, 0, &size, MEM_COMMIT, PAGE_READWRITE);

				if (error)
				{
					wchar[128] stringBuffer = void;
					reportErrorToUser(stringBuffer, "A partition of the parallel cosave buffer failed to grow.\r\nTHE GAME IS NOT FULLY SAVED.", error);
					return EXCEPTION_CONTINUE_SEARCH;
				}

				global.saveLoad.parallel.cosaveBufferCommitBixponent[partition] = commitBixponent;

				return EXCEPTION_CONTINUE_EXECUTION;
			}
		}

		if (global.saveLoad.cosaveFileBuffer.encloses(faultingAddress))
		{
			if (global.saveLoad.cosaveFileBuffer.commit >= global.saveLoad.cosaveFileBuffer.tail)
			{
				reportErrorToUser("The cosave file buffer has exceeded its maximum size.\r\nTHE GAME IS NOT FULLY SAVED.");
				return EXCEPTION_CONTINUE_SEARCH;
			}

			if ((error = global.saveLoad.cosaveFileBuffer.expandCommit) != 0)
			{
				wchar[128] stringBuffer = void;
				reportErrorToUser(stringBuffer, "The cosave file buffer failed to grow.\r\nTHE GAME IS NOT FULLY SAVED.", error);
				return EXCEPTION_CONTINUE_SEARCH;
			}

			return EXCEPTION_CONTINUE_EXECUTION;
		}
	}

	return EXCEPTION_CONTINUE_SEARCH;
}

