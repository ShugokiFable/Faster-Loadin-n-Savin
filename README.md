
# Faster Loadin' 'n' Savin'

> **Fork note (1.5.0):** this repository is a maintenance fork of [just-harry/save-load-accelerator-for-skse-cosaves](https://github.com/just-harry/save-load-accelerator-for-skse-cosaves), which is the original and upstream source. Version 1.5.0 is the renamed, audited public distribution and carries forward the crash-safe atomic cosave replacement, buffered sequential loading, Universal x86-64-v2 default build, optional x86-64-v3 High-End build, and compatibility work introduced by the maintenance fork. See [`changelog.md`](changelog.md). All credit for the original plugin remains with Harry Gillanders ("just-harry"); everything remains 0BSD-licensed.


> **Naming and compatibility note:** this public distribution is named **Faster Loadin and Savin**. The runtime DLL and INI retain their original `Save&LoadAcceleratorForSKSECosaves` filenames because the plugin locates those exact names internally. Renaming them without rebuilding the DLL would break startup and configuration loading.

This is a plugin for [SKSE64](https://skse.silverlock.org/) that aims to improve the performance of saving and loading SKSE cosave files.

## Verifying what you downloaded

This project ships a compiled DLL, and you should not have to take anyone's word
about what is inside it. **[`VERIFYING-RELEASES.md`](VERIFYING-RELEASES.md)**
documents exactly what each release contains and how to check it yourself with
`tools/verify-release-binaries.py` (Python standard library only, no
dependencies):

```
python tools/verify-release-binaries.py imports  <installed>\Save&LoadAcceleratorForSKSECosaves.dll
python tools/verify-release-binaries.py manifest <extracted release folder>
python tools/verify-release-binaries.py compare  <old>.dll <new>.dll
```

The `imports` subcommand prints every Windows API the DLL is able to call and
flags any networking, process-creation, remote-write, or persistence capability.
For every DLL in the 1.5.0 release it reports none: there is no socket, HTTP,
`CreateProcess`, `WriteProcessMemory`, registry, or `LoadLibrary` import in the
binary at all. Release hashes are published in
[`VERIFYING-RELEASES.md`](VERIFYING-RELEASES.md).

**1.5.0 contains no code changes from 1.4.0** -- it is the same binaries with
their version resources restamped and the package rearranged (Universal
x86-64-v2 is now the safe default; the AVX2 High-End build moved to `Optional/`).
`compare` demonstrates this: across all sixteen shipped DLLs the only differing
bytes are version strings, the version resource, and the PE checksum. `.text`,
the executable code, is identical.

## Building

### Requirements

- Windows PowerShell 5.1 or [PowerShell 7-and-later](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).
- The [LDC D compiler](https://github.com/ldc-developers/ldc).
- The [Clang C++ compiler](https://releases.llvm.org/) — or MSVC's `cl.exe`, which the build script substitutes automatically when clang++ is absent.
- A standard environment (e.g. the [MSVC Build Tools](https://learn.microsoft.com/cpp/build/building-on-the-command-line)) for targeting x86-64 Windows, specifically: having the Windows import libraries available via the library-path; having `rc` available via the `PATH`. `lld-link` is used when available, otherwise MSVC's `link.exe`.
- (Optional) [`7za`](https://www.7-zip.org/download.html) being available via the `PATH`, for packaging the built plugins.

### Procedure

In an environment for targeting x86-64 Windows, run the `build.ps1` script found in the root of this repository.
The resulting DLLs will be available in the `build/release` directory.
Pass `-TargetCPU x86-64-v3 -BuildTag -v3` for the high-end build, or `-TargetCPU x86-64-v2 -BuildTag -v2` for the universal build; each profile gets its own build directory.

To package the built DLLs into archives suitable for installation, run the `package.ps1` script found in the root of this repository.
The resulting archives will be available in the `package/release` directory.

## Licence

Unless otherwise specified, everything in this repository is licensed under the terms of the [BSD Zero Clause License](https://spdx.org/licenses/0BSD.html).

## Hitchhiker's Guide to the Codebase

This software has been written using D in the style of a better C—but the abominable C runtime is not used—and the D runtime also is not used, and the D standard-library is mostly avoided. \
Thus, a great deal of this repository is my own non-standard-library, found in `mod/slack_common`.

### Map
- [`mod/slack_common`](mod/slack_common): This module deals with functionality that's more-or-less generic.
	- [`mod/slack_common/algorithms.d`](mod/slack_common/algorithms.d): Vaguely algorithmic logic.
	- [`mod/slack_common/bindings.d`](mod/slack_common/bindings.d): Bindings for the compilation target: in this case, Windows.
	- [`mod/slack_common/byte_sizes.d`](mod/slack_common/byte_sizes.d): Because `64.MB` is clearer than `64 << 20`.
	- [`mod/slack_common/cpp.d`](mod/slack_common/cpp.d): Some bindings for Visual C++'s STL.
	- [`mod/slack_common/dynamic_linking.d`](mod/slack_common/dynamic_linking.d): Some convenience functions for dynamically linking with exports.
	- [`mod/slack_common/dynamically_linked.d`](mod/slack_common/dynamically_linked.d): A bit of a bodge to make dynamically-linked symbols available to `slack_common` without presupposing a storage method/layout for the pointers.
	- [`mod/slack_common/file_handling.d`](mod/slack_common/file_handling.d): Does what it says on the tin.
	- [`mod/slack_common/ini.d`](mod/slack_common/ini.d): Simple INI file parsing (lexing, really).
	- [`mod/slack_common/integers.d`](mod/slack_common/integers.d): Functions and whatnot for dealing with integer values.
	- [`mod/slack_common/large_low_overhead_buffer.d`](mod/slack_common/large_low_overhead_buffer.d): Buffers optimised for low-overhead writing into large and re-used regions of memory.
	- [`mod/slack_common/parsing.d`](mod/slack_common/parsing.d): Straightforward parsing and lexing routines.
	- [`mod/slack_common/patching.d`](mod/slack_common/patching.d): Utilities for examining, generating, and rewriting x86 machine code.
	- [`mod/slack_common/pe.d`](mod/slack_common/pe.d): Functionality for inspecting Portable Executable images.
	- [`mod/slack_common/peb_access.d`](mod/slack_common/peb_access.d): Support for peeking inside the process's Process Environment Block.
	- [`mod/slack_common/simd.d`](mod/slack_common/simd.d): The basics for x86 SIMD usage.
	- [`mod/slack_common/sorting.d`](mod/slack_common/sorting.d): Functions which can sort any array so long as its length is three.
	- [`mod/slack_common/text.d`](mod/slack_common/text.d): Simple text manipulation routines, including UTF-8<->UTF-16 conversion.
	- [`mod/slack_common/threading.d`](mod/slack_common/threading.d): Functions for controlling and synchronising threads.
	- [`mod/slack_common/tib_access.d`](mod/slack_common/tib_access.d): Support for reading and writing from and to a thread's Thread Information Block.
	- [`mod/slack_common/timing.d`](mod/slack_common/timing.d): Time matters.
	- [`mod/slack_common/user_interface.d`](mod/slack_common/user_interface.d): Frankly, this is just for popping up an error-message box when something invariably goes pear-shaped.
	- [`mod/slack_common/version.d`](mod/slack_common/version.d): A bunch of `enum bool` definitions so that we can use `static if` instead of `version`.
- [`mod/game`](mod/game): This module provides some basic infrastructure for introspecting which version/archetype of Skyrim SE we're targeting.
- [`mod/skse64`](mod/skse64): This module provides a minimal set of bindings for SKSE.
	- [`mod/skse64/hacks`](mod/skse64/hacks): This module isn't for bindings but instead for data and functions that assist in patching SKSE at runtime.
		- [`mod/skse64/hacks/versioning.d`](mod/skse64/hacks/versioning.d): Very simple: version-numbers and file-names for the latest version of SKSE for a given archetype of Skyrim SE.
		- [`mod/skse64/hacks/offsets.d`](mod/skse64/hacks/offsets.d): A table of offsets for places to patch SKSE at runtime.
- [`mod/slack_mod`](mod/slack_mod): This module implements the actual plugin proper.
	- [`mod/slack_mod/configuration.d`](mod/slack_mod/configuration.d): Defines the configurable state for the plugin.
	- [`mod/slack_mod/entrypoint.d`](mod/slack_mod/entrypoint.d): The entrypoint for the plugin's DLL, as well as any DLL exports, and the assert handler for debug builds.
	- [`mod/slack_mod/exception_wrapper.cpp`](mod/slack_mod/exception_wrapper.cpp): A small wrapper for calling a function and catching any exceptions it may throw.
	- [`mod/slack_mod/exception_wrapper.d`](mod/slack_mod/exception_wrapper.d): D bindings for the C++ exception wrapper.
	- [`mod/slack_mod/global.d`](mod/slack_mod/global.d): All the global state for the plugin, traceable from once place, and the vectored-exception-handler.
	- [`mod/slack_mod/limits.d`](mod/slack_mod/limits.d): Provides the definitions for any hardcoded limits for the plugin's functionality.
	- [`mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.def`](mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.def): Defines the exports of the plugin's DLL.
	- [`mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.rc`](mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.rc): Defines the product-version metadata for the plugin's DLL.
	- [`mod/slack_mod/save_load.d`](mod/slack_mod/save_load.d): The actual implementation of optimised saving and loading for SKSE cosave files.
	- [`mod/slack_mod/setup.d`](mod/slack_mod/setup.d): This file is responsible for installing the optimised saving/loading hooks at runtime, and generally setting up all the fiddly global state.
- [`mod/Save&LoadAcceleratorForSKSECosaves.ini`](mod/Save&LoadAcceleratorForSKSECosaves.ini): The default configuration file for the plugin.

