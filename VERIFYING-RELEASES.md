# Verifying releases

This project ships a compiled SKSE plugin. You should not have to take anyone's
word about what is inside a DLL, so this document explains exactly what each
release contains, how it was produced, and how to check it yourself.

Everything below can be reproduced with `tools/verify-release-binaries.py`,
which uses only the Python standard library.

## What 1.5.0 is

**1.5.0 contains no code changes.** It is the 1.4.0 binaries with their version
resources updated from `1.4.0` to `1.5.0`, plus repackaging:

- the public name became **Faster Loadin and Savin**,
- the FOMOD default changed to the Universal **x86-64-v2** build (the AVX2
  **x86-64-v3** build moved to `Optional/High-End (x86-64-v3)/`, so the default
  install can no longer fault with an illegal instruction on an older CPU),
- development debris (PDBs, object files, nested archives, source snapshots)
  was removed from the public archive.

The save/load implementation is byte-for-byte the 1.4.0 implementation.

## Checking that claim yourself

`compare` reports which PE *section* every differing byte falls in. Executable
code lives in `.text`; version metadata lives in `.rsrc` and in `.rdata`
strings; the header checksum changes whenever either does.

```
python tools/verify-release-binaries.py compare <1.4.0 build>.dll <1.5.0 shipped>.dll -v
```

Run against all sixteen shipped DLLs (eight game variants x two CPU profiles),
the result is the same every time:

```
7 differing byte(s) in 3 region(s):

  .rdata                            2 byte(s) in 2 range(s)
      0x007088-0x007088  34 -> 35
      0x008F1C-0x008F1C  34 -> 35
  .rsrc                             4 byte(s) in 4 range(s)
      0x00A090-0x00A090  04 -> 05
      0x00A098-0x00A098  04 -> 05
      0x00A1DC-0x00A1DC  34 -> 35
      0x00A418-0x00A418  34 -> 35
  OptionalHeader.CheckSum           1 byte(s) in 1 range(s)
      0x000140-0x000140  36 -> 3c

RESULT: no executable code differs.
```

`0x34` and `0x35` are the ASCII digits `4` and `5`. Every one of those bytes is
a `4` becoming a `5` inside a version number:

| Where | What it is |
|---|---|
| `.rdata` #1 | the error-dialog title string, `...Cosaves v1.4.0 Error` -> `v1.5.0` (see `mod/slack_common/user_interface.d`) |
| `.rdata` #2 | the embedded PDB path recorded by the linker, which contains the build directory name |
| `.rsrc` x4 | the `VS_VERSION_INFO` resource: binary `FILEVERSION`/`PRODUCTVERSION` fields and the `"1.4.0.0"` -> `"1.5.0.0"` strings (see the `.rc` file) |
| CheckSum | the PE image checksum, recomputed because the bytes above changed |

`.text` does not appear in that list for any of the sixteen files. No
executable code differs between 1.4.0 and 1.5.0.

## Release manifest (1.5.0)

Archive `Faster Loadin and Savin 1.5.0.zip`:

```
bc05c813d98f1e420942512f96ab5cee2b077616fcfd38892e11aeeb265ac5e7
```

DLLs, as reported by `verify-release-binaries.py manifest`:

```
76e7b388308e7b2dcf9b381b15b9aca64d2088b44e8b4326db0a2ea6b6062054  ae\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
10f80e1966656d30a2315842728a39225c377900c924a73e25b4fdd76dfdf736  ae1130\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
c1ba3f5b46c5babdea6b003f916aacd36dc2d5e855c80b9ddefedc5f03ef4de7  ae353\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
68d9492ec22cedad5b56614a0f659b261e9f81c9cead08167ff3693baf0f6d21  ae640\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
4f445e6f9fc68048e0b01ad23a243a255777e7656e361184c53e2e14c722f8f0  gog\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
87f590c64845821214ef0f6a7d85127ea09b29f3937f93747f27fc59914a145a  gog659\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
71837bc589aefb3a9673d7d3d9ec889016bcf92ca3c9be03aaf90761dfcdcea9  se\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
190936d42f5ba48dee7ef87aed968f8184909f13515b7b498637d4c5075b1eb2  vr\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
78ab6a3c0ed83c13053e3958c88e5c2f5f40e6fe8a63051afcdee3c1028e98ed  Optional\High-End (x86-64-v3)\ae\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
06fd51582b90fee2677cdf8d0e0f3e35908d85317df17167be1e02fc1708ed4b  Optional\High-End (x86-64-v3)\ae1130\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
5f063c0da764d84608247b5fe385acb7280bec521d7c00d99031e7a4301a20c2  Optional\High-End (x86-64-v3)\ae353\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
707fc72e61ce0d6665f38794752a26bd11ef3ff84f32fd091ccaef82c8f0ca67  Optional\High-End (x86-64-v3)\ae640\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
bee059c48543cc5eca1a7c62fd314a760017d058fe7fcaf53b5fe303a2a69913  Optional\High-End (x86-64-v3)\gog\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
10bef7d36deb69905674d648e265e0aec68d838be64dfd09d81de056793463a8  Optional\High-End (x86-64-v3)\gog659\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
3552c80676b9ef161c0918ace3791b5c08ea1b93ed8bdca7893c65f50c3d29e0  Optional\High-End (x86-64-v3)\se\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
205528ce2c580c9a109d0c053366779926662b6c729382d0b12d75ae043f02b1  Optional\High-End (x86-64-v3)\vr\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll
```

Reproduce with:

```
python tools/verify-release-binaries.py manifest "path\to\extracted\release"
```

## Building from source

The full source for the plugin is in this repository; see the Building section
of [`README.md`](README.md). The build needs the LDC D compiler, a C++
compiler (clang++ or MSVC `cl.exe`), `rc`, and a linker (`lld-link` or MSVC
`link.exe`).

Note that a from-source rebuild will not be bit-identical to the shipped DLLs:
the linker embeds an absolute PDB path and a timestamp, so the `.rdata` PDB
string and a handful of header bytes will reflect *your* build directory. The
`compare` subcommand exists precisely so those expected, environmental
differences can be told apart from a change in `.text`.

## What the plugin can do at runtime

A DLL can only call functions it imports. You do not have to trust a reading of
the source for this -- the import table is in the binary and cannot be talked
around:

```
python tools/verify-release-binaries.py imports <path to>\Save&LoadAcceleratorForSKSECosaves.dll
```

For the shipped SE build, that prints the **complete** list -- 36 symbols across
6 modules:

```
KERNEL32.dll  (9)   CreateFileA, CreateFileW, DeleteFileA,
                    DisableThreadLibraryCalls, FlushInstructionCache,
                    GetActiveProcessorCount, GetModuleFileNameW,
                    GetModuleHandleW, MoveFileExA
SHELL32.dll   (1)   ShellExecuteW
USER32.dll    (1)   MessageBoxW
VCRUNTIME140_1.dll (1)  __CxxFrameHandler4
ntdll.dll     (22)  LdrGetProcedureAddress, NtAllocateVirtualMemory, NtClose,
                    NtCreateSection, NtCreateThreadEx, NtFreeVirtualMemory,
                    NtMapViewOfSection, NtProtectVirtualMemory,
                    NtQueryInformationFile, NtQueryInformationThread,
                    NtQueryVirtualMemory, NtReadFile, NtSetInformationFile,
                    NtSetInformationThread, NtUnmapViewOfSection,
                    NtWaitForSingleObject, NtWriteFile,
                    RtlAddVectoredExceptionHandler, RtlExitUserProcess,
                    RtlQueryPerformanceCounter, RtlQueryPerformanceFrequency,
                    RtlRemoveVectoredExceptionHandler
ole32.dll     (2)   CoInitializeEx, CoUninitialize
```

(The other game variants import 32-35 symbols from the same modules; the
`imports` subcommand flags anything from a network, process-creation,
remote-write, or persistence API, and reports none for all sixteen DLLs.)

What is *absent* from that list is the point:

- **No networking.** No `ws2_32`, `wininet`, or `winhttp` module appears at all,
  so there is no socket, HTTP, or DNS capability of any kind. The plugin cannot
  phone home because it has no function with which to do so.
- **No process creation.** No `CreateProcess*`, no `WinExec`.
- **No process injection.** No `WriteProcessMemory`, `CreateRemoteThread`, or
  `VirtualAllocEx`.
- **No persistence.** No registry APIs, no scheduled-task or startup APIs.
- **No `LoadLibrary`.** Nothing is loaded from disk. (`LoadLibraryExW` has a
  *binding* in `mod/slack_common/bindings.d`, but it is never called -- which
  is why it does not appear in the import table. Dynamic linking is done with
  `GetModuleHandleW` + `LdrGetProcedureAddress` against `ntdll`, a module the
  process has already loaded.)

What it *does* use, and why:

| Imports | Purpose |
|---|---|
| `CreateFileA/W`, `NtReadFile`, `NtWriteFile`, `MoveFileExA`, `DeleteFileA`, `NtSetInformationFile`, `NtQueryInformationFile` | reading and writing the SKSE cosave and its `.tmp` staging file, at the path SKSE itself supplies, plus reading `Save&LoadAcceleratorForSKSECosaves.ini` |
| `NtAllocateVirtualMemory`, `NtFreeVirtualMemory`, `NtProtectVirtualMemory`, `NtQueryVirtualMemory`, `NtCreateSection`, `NtMapViewOfSection`, `NtUnmapViewOfSection` | the cosave buffers, and making SKSE's own code temporarily writable in order to patch it |
| `NtCreateThreadEx`, `NtWaitForSingleObject`, `NtSetInformationThread`, `NtQueryInformationThread`, `GetActiveProcessorCount` | the optional parallel-saving threads (disabled by default) |
| `FlushInstructionCache`, `RtlAddVectoredExceptionHandler`, `RtlRemoveVectoredExceptionHandler` | applying the runtime patch safely and growing buffers on demand |
| `MessageBoxW` | error dialogs |
| `ShellExecuteW`, `CoInitializeEx`, `CoUninitialize` | opening the SKSE download page in your browser **only** when the plugin detects an out-of-date SKSE and you click OK on that prompt; the single call site is in `mod/slack_mod/setup.d` (`isOutdatedSKSEVersion`) |

Patching SKSE's in-memory save/load routines is the entire point of the mod. It
is confined to the SKSE module's own code, and every offset used is listed
openly in `mod/skse64/hacks/offsets.d`.

## Reporting a concern

If you find something in this repository or in a release that contradicts the
above, please open an issue with the file, the offset, and how you found it.
Concrete reports are welcome and will be answered.
