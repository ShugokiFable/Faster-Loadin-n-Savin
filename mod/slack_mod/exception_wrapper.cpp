
/* SPDX-LICENSE-IDENTIFIER: 0BSD */


bool call_throws_exception (void *argument, void (*call) (void *))
{
	try
	{
		call(argument);
		return false;
	}
	catch (...)
	{
		return true;
	}
}

