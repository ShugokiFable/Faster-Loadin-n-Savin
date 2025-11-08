
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.file_handling;

import slack_common.bindings;


version (Windows)
{
	pragma(inline, true)
	void unmapFile (scope const(void)* memory) @trusted nothrow @nogc
	{
		NtUnmapViewOfSection(cast(HANDLE) -1, cast(void*) memory);
	}


	HRESULT mapFilePathForReading (scope const(wchar)* path, scope const(ubyte)[]* data) @trusted nothrow @nogc
	{
		HANDLE file = CreateFileW(
			path,
			GENERIC_READ,
			FILE_SHARE_READ,
			null,
			OPEN_EXISTING,
			FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
			null
		);

		if (file == INVALID_HANDLE_VALUE) return hresultFromLastError(GetLastError);

		HRESULT error = mapFileForReading(file, data);

		NtClose(file);

		if (error) return error;

		return 0;
	}


	pragma(inline, true)
	HRESULT mapFileForReading (HANDLE file, scope const(ubyte)[]* data) @trusted nothrow @nogc
	{
		return mapFileIntoMemory(file, cast(ubyte[]*) data, SECTION_MAP_READ, PAGE_READONLY);
	}


	HRESULT mapFileIntoMemory (HANDLE file, scope ubyte[]* data, uint mappingFlags, uint memoryFlags) @trusted nothrow @nogc
	{
		NTSTATUS error = void;
		IO_STATUS_BLOCK ioStatusBlock = void;
		FILE_STANDARD_INFORMATION fileInfo = void;
		HANDLE section = void;
		void* address = null;
		size_t viewSize = 0;

		error = NtQueryInformationFile(file, &ioStatusBlock, &fileInfo, fileInfo.sizeof, FILE_INFORMATION_CLASS.FileStandardInformation);

		if (error) return error;

		error = NtCreateSection(&section, mappingFlags, null, null, memoryFlags, SEC_COMMIT, file);

		if (error) return error;

		error = NtMapViewOfSection(section, cast(HANDLE) -1, &address, 0, 0, null, &viewSize, ViewUnmap, 0, memoryFlags);

		/+ The view doesn't need the section handle to remain open, so let's close it unconditionally. +/
		NtClose(section);

		if (error) return error;

		*data = (cast(ubyte*) address)[0 .. cast(size_t) fileInfo.EndOfFile];

		return 0;
	}
}

