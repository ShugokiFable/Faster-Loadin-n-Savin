
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.sorting;

import slack_common.memory;


pragma(inline, true)
void sortingNetwork (alias greaterThan, T, size_t size) (scope ref T[size] v)
{
	enum string ce (string a, string b) = (
		"branchlessSwap(greaterThan(v[" ~ a ~ "], v[" ~ b ~ "]), v[" ~ a ~ "], v[" ~ b ~ "]);"
	);

	static if (size == 3)
	{
		mixin(ce!(q{0}, q{2}));
		mixin(ce!(q{0}, q{1}));
		mixin(ce!(q{1}, q{2}));
	}
	else
	{
		static assert(false);
	}
}


pragma(inline, true)
private void branchlessSwap (T) (bool swap, scope ref T a, scope ref T b)
{
	static if (T.sizeof <= 32)
	{
		T c = a;
		a = swap ? b : a;
		b = swap ? c : b;
	}
	else
	{
		T c = void;
		blit(&c, &a);
		blit(&a, swap ? &b : &a);
		blit(&b, swap ? &c : &b);
	}
}

