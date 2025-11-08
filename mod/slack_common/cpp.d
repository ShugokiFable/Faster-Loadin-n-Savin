
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.cpp;


struct std_basic_string (Char)
{
	Char* base;
	size_t capacity;
	size_t size;

	alias asSlice this;

	pragma(inline, true)
	inout(Char)[] asSlice () inout @property return scope @trusted pure nothrow @nogc
	{
		return this.base[0 .. this.size];
	}
}


alias std_string = std_basic_string!char;


struct std_vector (T)
{
	T* base;
	T* tail;

	alias asSlice this;

	pragma(inline, true)
	inout(T)[] asSlice () inout @property return scope @trusted pure nothrow @nogc
	{
		return this.base[0 .. this.tail - this.base];
	}

	pragma(inline, true)
	size_t size () const @property scope @safe pure nothrow @nogc
	{
		return this.tail - this.base;
	}
}

