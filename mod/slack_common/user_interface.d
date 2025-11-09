
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.user_interface;

import slack_common.bindings;
import slack_common.memory;
import slack_common.text;


enum immutable(wchar[]) errorDialogTitle = "Save & Load Accelerator for SKSE Cosaves v1.0.4 Error";


void reportErrorToUser (scope const(wchar)* message, uint flags = MB_ICONERROR) nothrow @nogc
{
	MessageBoxW(
		null,
		message,
		errorDialogTitle.ptr,
		MB_OK | MB_TOPMOST | flags
	);
}


void reportErrorToUser (
	scope wchar[] stringBuffer,
	scope const(wchar)[] message,
	uint errorCode = 0,
	uint flags = MB_ICONERROR
) nothrow @nogc
in (message.length < stringBuffer.length)
in (errorCode == 0 || ((stringBuffer.length >= 28) & (stringBuffer.length - 27 > message.length)))
{
	wchar* s = stringBuffer.ptr;
	blit(s, message.ptr, message.length);
	s += message.length;

	if (errorCode != 0)
	{
		blit(s, "\r\nOS Error Code: 0x"w.ptr, 19);
		s += 19;
		errorCode.asHexInto!true(s[0 .. 8]);
		s += 8;
	}

	*s = '\0';

	reportErrorToUser(stringBuffer.ptr, flags);
}

