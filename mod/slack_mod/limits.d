
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_mod.limits;

import slack_common.byte_sizes;


enum ubyte parallelSaveLoadThreadCountLimit = 128;
enum ushort parallelCosaveAwarePluginCountLimit = 512;
enum uint maximumCosaveFileSize = 512.MB;

