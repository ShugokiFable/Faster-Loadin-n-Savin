
# Save & Load Accelerator for SKSE Cosaves: Changelog

## Version 1.2.0 (2025-11-13)

The tenth release of this plugin, the changes are as follows:
- A profiling mode has been added: when enabled, the time taken for each SKSE plugin to save and-or load will be logged to the in-game console.
- An oversight, introduced by version 1.0.2, which caused the plugin's DLL to be roughly 9 KB larger than necessary was corrected.
- The memory-usage of each thread used for parallel-saving has been reduced slightly.
- When logging errors related to a SKSE plugin's usage of the cosave saving/loading API, the identifier of the offending plugin is now also logged.
- The alignment of timings logged to the console have been changed to fit what they were intended to be.

---

The song recommendation for this release is [isui's cover of "Smoky quartz" by Komiya Cofey](https://www.youtube.com/watch?v=_tYbmNb4VVQ).

## Version 1.1.0 (2025-11-11)

Something about that date rings a bell, doesn't it?

The ninth release of this plugin, the changes are as follows:
- The plugin is now packaged as a FOMOD, with automatic game-version detection. (Individual zip-archives are still available on GitHub.)
- A fix for blank error-message dialogs on version 1.5.97 of Skyrim SE.
- A more robust stratagem for allocating memory closely to the SKSE DLL.
- Version detection for ten outdated versions of SKSE has been implemented.
- The requirement for Windows 10, version 1803 has been dropped—the plugin can run on Window Vista now. (Parallel-saving still requires Windows 8 or newer.)
- A very small oversight that could cause the save-timing logging to not log was corrected.
- Version 2.2.5 of SKSE is now supported, for users of version 1.6.1130 of Skyrim SE.
---

The song recommendation for this release is ["Present" by TOMOO](https://www.youtube.com/watch?v=EvpsZde4QSI).

## Version 1.0.7 (2025-11-09)

The eighth release of this plugin, the changes are as follows:
- File-paths containing non-ASCII characters no longer cause saves to fail to load nor cause save creation to fail. \
(Ironically, my efforts to fully support Unicode were what caused this issue, as the rest of the game's code relies on the restricted code-page of the system/user's locale.)
---

The song recommendation for this release is ["帰天" by 塚越雄一朗, featuring 皇黄リリエ](https://www.youtube.com/watch?v=ctO6lUgrBGU).

## Version 1.0.6 (2025-11-09)

The seventh release of this plugin, the changes are as follows:
- An issue which could cause save files to fail to open may have been fixed.
---

The song recommendation for this release is ["Rocking Son Of Dschinghis Khan" by, uhh, Dschinghis Khan](https://www.youtube.com/watch?v=pqWc5FABmDY). \
I'm slightly ashamed to admit that this song is in my personal top-ten going by listen-count.

## Version 1.0.5 (2025-11-09)

The sixth release of this plugin, the changes are as follows:
- Support for version 2.1.5 of SKSE has been fixed, for users of version 1.6.353 of Skyrim SE.
---

The song recommendation for this release is ["雨は毛布のように" by KIRINJI](https://www.youtube.com/watch?v=HWyyxJoZHyY).

## Version 1.0.4 (2025-11-09)

The fifth release of this plugin, the changes are as follows:
- A crash that could occur when launching the game may have been fixed.
---

The song recommendation for this release is ["Declaration of Complete Resignation" by Nanawo Akari](https://www.youtube.com/watch?v=Vi_asBY5UX8) \
Don't read too much into that choice ;)

## Version 1.0.3 (2025-11-09)

The fourth release of this plugin, the changes are as follows:
- Version 2.1.5 of SKSE is now supported, for users of version 1.6.353 of Skyrim SE.
- A workaround for a bug in "STB Widgets" versions 1.6-to-1.9 has been added. (The bug is that it supplies an invalid memory-address to SKSE's saving routines).
- The handling of default values for booleans in the INI configuration file has been improved.
---

The song recommendation for this release is [this live performance of Kotringo's cover of 恋とマシンガン](https://www.youtube.com/watch?v=mygM8L3fpa0).

## Version 1.0.2 (2025-11-09)

The third release of this plugin, the changes are as follows:
- Support for version 2.0.20 of SKSE has been fixed, for users of version 1.5.97 of Skyrim SE.
- The version of the plugin is now displayed in the title of error-message dialogs.
---

The song recommendation for this release is ["白雪 Evil Snow" by Hatsuki Yura](https://www.youtube.com/watch?v=V687A50cPQ8).

## Version 1.0.1 (2025-11-09)

The second release of this plugin, the changes are as follows:
- Versions 2.2.3 and 2.2.3 (GOG) of SKSE are now supported, for users of version 1.6.640/1.6.659 of Skyrim SE.
- A slightly different method of finding the SKSE DLL is now used.
---

The song recommendation for this release is ["Just Me and My Dog" by Club des Belugas, featuring vocals by Anna Luca](https://www.youtube.com/watch?v=agSoHWRpvxI).

## Version 1.0.0 (2025-11-08)

The first release of this plugin, the features provided are as follows:
- Acceleration of SKSE cosave saving and loading.
- Console logging of the time taken to save or load a SKSE cosave.
- Experimental support for saving the data of multiple SKSE plugins to a SKSE cosave in parallel.
- Support for the AE, SE, VR, and GOG versions of SKSE.

---

The song recommendation for this release is ["10周年目突入記念公演"大拍乱会"メドレー" by CHARAN-PO-RANTAN](https://www.youtube.com/watch?v=fuIDO1_3oSE).

