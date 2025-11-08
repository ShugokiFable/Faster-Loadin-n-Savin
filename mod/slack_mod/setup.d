
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_mod.setup;

import game;

import slack_common.algorithms;
import slack_common.bindings;
import slack_common.byte_sizes;
import slack_common.cpp;
import slack_common.file_handling;
import slack_common.ini;
import slack_common.integers;
import slack_common.large_low_overhead_buffer;
import slack_common.memory;
import slack_common.patching;
import slack_common.pe;
import slack_common.peb_access;
import slack_common.text;
import slack_common.threading;
import slack_common.tib_access;
import slack_common.user_interface;
import slack_mod.configuration;
import slack_mod.global;
import slack_mod.limits;
import slack_mod.save_load;

import skse64.dll_plugins;
import skse64.serialisation;
import skse64.hacks.versioning;
import skse64.hacks.offsets;


bool setUpEverything (
	return scope ref wchar[MAX_PATH + 60] stringBuffer
) nothrow @nogc
{
	alias Config = ConfigurationLongLived.Flags;

	RtlQueryPerformanceFrequency(cast(LARGE_INTEGER*) &global.performanceFrequency);

	global.performanceFrequencyMillisecondMultiplier = 1000.0 / cast(double) global.performanceFrequency;

	uint error = void;
	const(wchar)[] errorMessage = void;
	const(ubyte)[] ini = void;
	const(wchar)* skseDLLName = void;
	ushort skseDLLNameLength = void;

	global.configuration.setToDefault;

	ConfigurationTransient transientConfiguration = void;
	transientConfiguration.setToDefault;

	const(wchar)* endOfINIPath = findConfigurationFilePath(stringBuffer, global.dllModule);

	if (endOfINIPath == null)
	{
		reportErrorToUser(
			stringBuffer,
			"The path of the \"Save&LoadAcceleratorForSKSECosaves.dll\" file could not be found.\r\nAnd thus nor can the INI file be found.",
			hresultFromLastError(getLastError)
		);
	noINIFile:
		ini = null;
		skseDLLName = defaultSKSE64DLLNameUTF16.ptr;
		skseDLLNameLength = defaultSKSE64DLLNameUTF16.length;
	}
	else
	{
		HANDLE iniFile = CreateFileW(
			stringBuffer.ptr,
			GENERIC_READ,
			FILE_SHARE_READ,
			null,
			OPEN_EXISTING,
			FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
			null
		);

		if (iniFile == INVALID_HANDLE_VALUE)
		{
			if ((error = getLastError) != ERROR_FILE_NOT_FOUND)
			{
				reportErrorToUser(
					stringBuffer,
					"The \"Save&LoadAcceleratorForSKSECosaves.ini\" file could not be opened.",
					hresultFromLastError(error)
				);
			}

			goto noINIFile;
		}
		else
		{
			error = mapFileForReading(iniFile, &ini);

			NtClose(iniFile);

			if (error)
			{
				reportErrorToUser(
					stringBuffer,
					"The \"Save&LoadAcceleratorForSKSECosaves.ini\" file could not be mapped for reading.",
					error
				);

				goto noINIFile;
			}

			parseINIConfiguration(cast(const(char)[]) ini, &global.configuration, &transientConfiguration);

			if (transientConfiguration.skseDLLName.length != 0)
			{
				const(char)* utf8 = transientConfiguration.skseDLLName.ptr;
				const(char)* utf8End = transientConfiguration.skseDLLName.endOf;
				wchar* utf16 = stringBuffer.ptr;
				wchar* utf16End = stringBuffer.endOf - 1;
				dchar pendingCodePoint = cast(dchar) -1;
				utf8ToUTF16(&utf8, utf8End, &utf16, utf16End, &pendingCodePoint);

				if (utf8 < utf8End)
				{
					reportErrorToUser(
						"The \"SKSEDLLName\" value provided in \"Save&LoadAcceleratorForSKSECosaves.ini\" is too long."
					);

					goto defaultSKSEDLLName;
				}

				*utf16 = '\0';

				skseDLLName = stringBuffer.ptr;
				skseDLLNameLength = cast(ushort) (cast(size_t) (utf16 - skseDLLName));
			}
			else
			{
			defaultSKSEDLLName:
				skseDLLName = defaultSKSE64DLLNameUTF16.ptr;
				skseDLLNameLength = defaultSKSE64DLLNameUTF16.length;
			}
		}
	}

	scope(exit) if (ini !is null)
	{
		unmapFile(ini.ptr);
	}

	if (global.configuration.skseHooksAreRequired)
	{
		ubyte* skseDLL = void;

		auto skseDLLNameString = const(UNICODE_STRING).from(skseDLLName, skseDLLNameLength);
		if ((error = LdrGetDllHandle(null, null, &skseDLLNameString, cast(HMODULE*) &skseDLL)) != 0)
		{
			reportErrorToUser(
				stringBuffer,
				"The SKSE64 DLL could not be found.\r\nYou may need to set, or change, the value of the \"SKSEDLLName\" setting in the \"Save&LoadAcceleratorForSKSECosaves.ini\" file.",
				error
			);
			return false;
		}

		PESections sections = void;

		if (findSectionsOfPE64(skseDLL, &sections) != 0)
		{
			reportErrorToUser("Some sections expected to be found in the SKSE64 DLL are missing.");
			return false;
		}

		global.addressOf.globalSKSE64Provider = cast(SKSE64Provider*) (sections.rdata.ptr + skse64Offsets.globalSKSE64Provider);

		if (global.addressOf.globalSKSE64Provider.skse64Version != expectedSKSE64Version)
		{
			wchar* s = stringBuffer.ptr;
			blit(s, "This version of the SKSE64 DLL is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\nPlease ensure you are using the correct version of S.L.A.C.K. for your version of the game.\r\n"w.ptr, 204);
			s += 204;
			blit(s, "Expected version: 0x"w.ptr, 20);
			s += 20;
			expectedSKSE64Version.asHexInto!true(s[0 .. 8]);
			s += 8;
			blit(s, "; Actual version: 0x"w.ptr, 20);
			s += 20;
			global.addressOf.globalSKSE64Provider.skse64Version.asHexInto!true(s[0 .. 8]);
			s += 8;
			*s++ = '.';
			*s++ = '\0';
			reportErrorToUser(stringBuffer.ptr);
			return false;
		}

		MEM_ADDRESS_REQUIREMENTS _32BitAddressRange = {
			LowestStartingAddress: sections.lastInMemory.endOf.alignUpTo(allocationGranularity) - 2.GB,
			HighestEndingAddress: sections.firstInMemory.ptr.alignDownTo(allocationGranularity) + 2.GB - 1
		};
		MEM_EXTENDED_PARAMETER requirement = {
			Type: MEM_EXTENDED_PARAMETER_TYPE.MemExtendedParameterAddressRequirements,
			Pointer: &_32BitAddressRange
		};

		void* skseAdjacentMemory = null;
		size_t size = 64.KB;
		if ((error = NtAllocateVirtualMemoryEx(thisProcess, &skseAdjacentMemory, &size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE, &requirement, 1)) != 0)
		{
			errorMessage = "Memory could not be allocated sufficiently close to the SKSE64 DLL.";
		reportErrorOnFailure:
			reportErrorToUser(stringBuffer, errorMessage, error);
			return false;
		}

		/+ To increase the likelihood of other mods patching SKSE being able
		   to allocate within a 32-bit range of SKSE, we specifically avoid allocating
		   within that range from hereon. +/

		MEM_ADDRESS_REQUIREMENTS beforeSKSEAddressRange = {
			LowestStartingAddress: null,
			HighestEndingAddress: _32BitAddressRange.LowestStartingAddress - 1
		};

		MEM_ADDRESS_REQUIREMENTS afterSKSEAddressRange = {
			LowestStartingAddress: _32BitAddressRange.HighestEndingAddress + 1,
			HighestEndingAddress: null
		};

		requirement.Pointer = &beforeSKSEAddressRange;
		if ((error = makeLargeAndLowOverheadSequentialBuffer(&global.saveLoad.cosaveFileBuffer, maximumCosaveFileSize, 1.MB, (&requirement)[0 .. 1])) != 0)
		{
			requirement.Pointer = &afterSKSEAddressRange;
			if ((error = makeLargeAndLowOverheadSequentialBuffer(&global.saveLoad.cosaveFileBuffer, maximumCosaveFileSize, 1.MB, (&requirement)[0 .. 1])) != 0)
			{
				errorMessage = "Memory could not be allocated for the cosave file buffer.";
			errorWithSKSEAdjacentMemory:
				size = 0;
				NtFreeVirtualMemory(thisProcess, &skseAdjacentMemory, &size, MEM_RELEASE);
				goto reportErrorOnFailure;
			}
		}

		const(ubyte)* cosaveSaveFunction = void;
		const(ubyte)* cosaveLoadFunction = void;

		/+ "`goto` skips declaration of variable".
		   Why must every edge of D be razor sharp? +/
		ubyte parallelThreadCount = void;
		const(void)* stackBase = void;
		const(void)* stackLimit = void;
		size_t stackReservation = void;
		HANDLE threadHandle = void;
		size_t threadIndex = void;

		if (global.configuration.parallelismEnabled)
		{
			parallelThreadCount = global.configuration.adjustThreadCounts;

			global.saveLoad.parallel.threadCount = parallelThreadCount;

			requirement.Pointer = &beforeSKSEAddressRange;
			if ((error = makeLargeAndLowOverheadPartitionedBuffer(&global.saveLoad.parallel.cosaveBuffer, maximumCosaveFileSize.integralLog2, parallelThreadCount, (&requirement)[0 .. 1])) != 0)
			{
				requirement.Pointer = &afterSKSEAddressRange;
				if ((error = makeLargeAndLowOverheadPartitionedBuffer(&global.saveLoad.parallel.cosaveBuffer, maximumCosaveFileSize.integralLog2, parallelThreadCount, (&requirement)[0 .. 1])) != 0)
				{
					errorMessage = "Memory could not be allocated for the parallel cosave buffer.";
				errorWithCosaveFileBuffer:
					global.saveLoad.cosaveFileBuffer.free;
					goto errorWithSKSEAdjacentMemory;
				}
			}

			stackBase = readFromTIB!(const(void)*, int(NT_TIB.StackBase.offsetof));
			stackLimit = readFromTIB!(const(void)*, int(NT_TIB.StackLimit.offsetof));

			/+ We'll reserve the same amount of stack space as the main thread, to ensure compatibility. +/
			stackReservation = stackBase - stackLimit;

			for (threadIndex = 0; threadIndex < parallelThreadCount; ++threadIndex)
			{
				error = makeThread(
					&threadHandle,
					&parallelSaveLoadThreadProcedureEntry!(),
					cast(void*) threadIndex,
					0,
					1.MB,
					greaterOf(stackReservation, 1.MB)
				);

				if (error)
				{
					errorMessage = "A thread could not be created for parallel cosave handling.";
				errorWithParallelCosaveThreads:
					while (threadIndex != 0)
					{
						--threadIndex;
						threadHandle = global.saveLoad.parallel.threadHandles[threadIndex];
						NtClose(threadHandle);
					}

					goto errorWithCosaveFileBuffer;
				}

				global.saveLoad.parallel.threadHandles[threadIndex] = threadHandle;
			}

			cosaveSaveFunction = cast(const(ubyte)*) (
				  (global.configuration.flags & Config.enableParallelSaving)
				? &saveCosaveParallel
				: &saveCosaveSerial
			);

			cosaveLoadFunction = cast(const(ubyte)*) &loadCosaveSerial;
		}
		else
		{
			cosaveSaveFunction = cast(const(ubyte)*) &saveCosaveSerial;
			cosaveLoadFunction = cast(const(ubyte)*) &loadCosaveSerial;
		}

		void* exceptionHandler = RtlAddVectoredExceptionHandler(1, &vectoredExceptionHandler!());

		if (exceptionHandler == null)
		{
			errorMessage = "The vectored-exception-handler could not be registered.";
		errorWithVectoredExceptionHandler:
			RtlRemoveVectoredExceptionHandler(exceptionHandler);

			if (global.configuration.parallelismEnabled)
			{
				goto errorWithParallelCosaveThreads;
			}
			else
			{
				goto errorWithSKSEAdjacentMemory;
			}
		}

		global.addressOf.skseCosaveSavePath = cast(std_string*) (sections.data.ptr + skse64Offsets.cosaveSavePath);
		global.addressOf.cosaveAwarePlugins = cast(std_vector!SerialisationStateForPlugin*) (sections.data.ptr + skse64Offsets.cosaveAwarePlugins);
		global.addressOf.skseInitialiseCall = sections.text.ptr + skse64Offsets.initialiseCall;
		global.addressOf.createSKSECosave = sections.text.ptr + skse64Offsets.createCosave;
		global.addressOf.restoreSKSECosave = sections.text.ptr + skse64Offsets.restoreCosave;
		global.addressOf.createSKSECosaveCall = sections.text.ptr + skse64Offsets.createCosaveCall;
		global.addressOf.restoreSKSECosaveCall = sections.text.ptr + skse64Offsets.restoreCosaveCall;
		global.addressOf.skseConsolePrint = cast(typeof(global.addressOf.skseConsolePrint)) (sections.text.ptr + skse64Offsets.consolePrint);

		const(ubyte)* skseInitialise = x86TargetOf!5(global.addressOf.skseInitialiseCall);

		ubyte* code = cast(ubyte*) skseAdjacentMemory;
		ubyte* c = code;

		ubyte* skseInitialiseHook = c;

		static if (targetedGameArchetype != GameArchetype.se)
		{
			*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 5, 4); *c++ = 40;             /+ sub rsp, 40 +/
			c.writeDirectCallOf(skseInitialise); c += 5;                             /+ call skseInitialise +/
			*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 0, 4); *c++ = 40;             /+ add rsp, 40 +/
			c += c.writeJumpTo(cast(const(ubyte)*) &setUpAfterInitialisationOfSKSE); /+ jmp setUpAfterInitialisationOfSKSE +/

			withCodeRegionMadeWritable(
				global.addressOf.skseInitialiseCall,
				5,
				(scope ubyte* a, size_t s) {a.writeDirectCallOf(skseInitialiseHook);}
			);
		}
		else
		{
			/+ SE is slightly different here in that `skseInitialiseCall`
			   is a jmp instead of a call. +/
			*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 5, 4); *c++ = 32;             /+ sub rsp, 32 +/
			c.writeDirectCallOf(skseInitialise); c += 5;                             /+ call skseInitialise +/
			*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 0, 4); *c++ = 32;             /+ add rsp, 32 +/
			c += c.writeJumpTo(cast(const(ubyte)*) &setUpAfterInitialisationOfSKSE); /+ jmp setUpAfterInitialisationOfSKSE +/

			withCodeRegionMadeWritable(
				global.addressOf.skseInitialiseCall,
				5,
				(scope ubyte* a, size_t s) {a.writeNearJumpTo(skseInitialiseHook);}
			);
		}

		version (SLACKVerificationMode)
		{
			enum bool replaceSaveCosave = false;
		}
		else
		{
			bool replaceSaveCosave = (global.configuration.flags & Config.accelerateSaving) != 0;
		}

		if (replaceSaveCosave)
		{
			c = c.alignUpTo(16);
			ubyte* createCosaveReplacement = c;
			c += c.writeJumpTo(cosaveSaveFunction); /+ jmp cosaveSaveFunction +/

			withCodeRegionMadeWritable(
				global.addressOf.createSKSECosave,
				5,
				(scope ubyte* a, size_t s) {a.writeNearJumpTo(createCosaveReplacement);}
			);

			FlushInstructionCache(thisProcess, global.addressOf.createSKSECosave, 5);
		}
		else if (global.configuration.flags & Config.logSaveTimingsToConsole)
		{
			version (SLACKVerificationMode)
			{
				const(ubyte)* createSKSECosaveCallTarget = cast(const(ubyte)*) &saveCosaveInVerificationMode;
			}
			else
			{
				const(ubyte)* createSKSECosaveCallTarget = x86TargetOf!5(global.addressOf.createSKSECosaveCall);
			}

			c = c.alignUpTo(16);
			ubyte* createCosaveCallReplacement = c;
			*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 5, 4); *c++ = 40;               /+ sub rsp, 40 +/
			c += c.writeCallOf(cast(const(ubyte)*) &logUnpatchedSaveLoadTimingBefore); /+ call logUnpatchedSaveLoadTimingBefore +/
			version (SLACKVerificationMode)
			{
				c += c.writeCallOf(createSKSECosaveCallTarget);          /+ call createSKSECosaveCallTarget +/
			}
			else
			{
				c.writeDirectCallOf(createSKSECosaveCallTarget); c += 5; /+ call createSKSECosaveCallTarget +/
			}
			*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 0, 4); *c++ = 40;               /+ add rsp, 40 +/
			c += c.writeJumpTo(cast(const(ubyte)*) &logUnpatchedSaveTimingAfter);      /+ jmp logUnpatchedSaveTimingAfter +/

			withCodeRegionMadeWritable(
				global.addressOf.createSKSECosaveCall,
				5,
				(scope ubyte* a, size_t s) {a.writeDirectCallOf(createCosaveCallReplacement);}
			);

			FlushInstructionCache(thisProcess, global.addressOf.createSKSECosaveCall, 5);
		}

		if (global.configuration.flags & Config.accelerateLoading)
		{
			c = c.alignUpTo(16);
			ubyte* restoreCosaveReplacement = c;
			c += c.writeJumpTo(cosaveLoadFunction); /+ jmp cosaveLoadFunction +/

			withCodeRegionMadeWritable(
				global.addressOf.restoreSKSECosave,
				5,
				(scope ubyte* a, size_t s) {a.writeNearJumpTo(restoreCosaveReplacement);}
			);

			FlushInstructionCache(thisProcess, global.addressOf.restoreSKSECosave, 5);
		}
		else if (global.configuration.flags & Config.logLoadTimingsToConsole)
		{
			const(ubyte)* restoreSKSECosaveCallTarget = x86TargetOf!5(global.addressOf.restoreSKSECosaveCall);

			c = c.alignUpTo(16);
			ubyte* restoreCosaveCallReplacement = c;
			*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 5, 4); *c++ = 40;               /+ sub rsp, 40 +/
			c += c.writeCallOf(cast(const(ubyte)*) &logUnpatchedSaveLoadTimingBefore); /+ call logUnpatchedSaveLoadTimingBefore +/
			c.writeDirectCallOf(restoreSKSECosaveCallTarget); c += 5;                  /+ call restoreSKSECosaveCallTarget +/
			*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 0, 4); *c++ = 40;               /+ add rsp, 40 +/
			c += c.writeJumpTo(cast(const(ubyte)*) &logUnpatchedLoadTimingAfter);      /+ jmp logUnpatchedLoadTimingAfter +/

			withCodeRegionMadeWritable(
				global.addressOf.restoreSKSECosaveCall,
				5,
				(scope ubyte* a, size_t s) {a.writeDirectCallOf(restoreCosaveCallReplacement);}
			);

			FlushInstructionCache(thisProcess, global.addressOf.restoreSKSECosaveCall, 5);
		}

		version (SLACKVerificationMode)
		{
			size_t regionSize = 512.MB;
			NtAllocateVirtualMemory(thisProcess, cast(void**) &global.saveLoad.verificationBase, 0, &regionSize, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
			global.saveLoad.verificationTail = global.saveLoad.verificationBase + regionSize;

			const(ubyte)* restoreSKSECosaveCallTarget = cast(const(ubyte)*) &callLoadCosaveInVerificationMode;

			c = c.alignUpTo(16);
			ubyte* restoreCosaveCallReplacement = c;
			c += c.writeJumpTo(restoreSKSECosaveCallTarget); /+ jmp restoreSKSECosaveCallTarget +/

			withCodeRegionMadeWritable(
				global.addressOf.restoreSKSECosaveCall,
				5,
				(scope ubyte* a, size_t s) {a.writeDirectCallOf(restoreCosaveCallReplacement);}
			);

			FlushInstructionCache(thisProcess, global.addressOf.restoreSKSECosaveCall, 5);
		}

		makeMemoryRegionExecutable(code, 4.KB);

		FlushInstructionCache(thisProcess, code, 4.KB);
		FlushInstructionCache(thisProcess, global.addressOf.skseInitialiseCall, 5);
	}

	return true;
}


void setUpAfterInitialisationOfSKSE () nothrow @nogc
{
	alias Config = ConfigurationLongLived.Flags;

	SerialisationProvider* serialisationProvider = cast(SerialisationProvider*) (
		global.addressOf.globalSKSE64Provider.requestProvider(SKSE64Provider.ProviderID.serialisation)
	);

	global.addressOf.globalSerialisationProvider = serialisationProvider;

	if (global.configuration.accelerationEnabled)
	{
		withRegionMadeWritable(
			cast(ubyte*) serialisationProvider,
			SerialisationProvider.sizeof,
			(scope ubyte* a, size_t s)
			{
				SerialisationProvider* serialisation = cast(SerialisationProvider*) a;

				version (SLACKVerificationMode)
				{
					global.addressOf.skseSerialisationBeginRecord = serialisation.beginRecord;
					global.addressOf.skseSerialisationWriteRecord = serialisation.writeRecord;
					global.addressOf.skseSerialisationWriteRecordData = serialisation.writeRecordData;
				}

				if (global.configuration.flags & Config.accelerateSaving)
				{
					serialisation.beginRecord = &SerialSaving.beginRecord;
					serialisation.writeRecord = &SerialSaving.writeRecord;
					serialisation.writeRecordData = &SerialSaving.writeRecordData;
				}

				version (SLACKVerificationMode)
				{
					if (global.configuration.flags & Config.accelerateLoading)
					{
						global.addressOf.readNextRecordHeader = &SerialLoading.readNextRecordHeader;
						global.addressOf.readRecordData = &SerialLoading.readRecordData;
					}
					else
					{
						global.addressOf.readNextRecordHeader = serialisation.readNextRecordHeader;
						global.addressOf.readRecordData = serialisation.readRecordData;
					}

					serialisation.readNextRecordHeader = &VerifiedLoading.readNextRecordHeader;
					serialisation.readRecordData = &VerifiedLoading.readRecordData;
				}
				else
				{
					if (global.configuration.flags & Config.accelerateLoading)
					{
						serialisation.readNextRecordHeader = &SerialLoading.readNextRecordHeader;
						serialisation.readRecordData = &SerialLoading.readRecordData;
					}
				}
			}
		);
	}
}

