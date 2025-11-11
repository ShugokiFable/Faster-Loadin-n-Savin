
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.dynamically_linked;


import slack_mod.global : global;


pragma(inline, true)
ref auto linked () () @property
{
	return global.linked;
}

