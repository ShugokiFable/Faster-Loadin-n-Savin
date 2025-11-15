
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_mod.exception_wrapper;


/+ LDC does actually support catching C++ exceptions from D code.
   ...But not in BetterC mode :(
   Hence this. +/


extern(C++) bool call_throws_exception (scope void* argument, void function (void*) call) nothrow @nogc;


pragma(inline, true)
bool callThrowsException (T, U) (scope T argument, scope U call)
{
	alias Callee = extern(C++) void function (void*) nothrow @nogc;

	return call_throws_exception(cast(void*) argument, cast(Callee) call);
}

