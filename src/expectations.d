/++
Error handling that bundles exceptions with return values.

The design of this module is based on C++'s proposed
[std::expected](https://wg21.link/p0323), and is also similar to Rust's
[std::result](https://doc.rust-lang.org/std/result/). See
["Expect the Expected"](https://www.youtube.com/watch?v=nVzgkepAg5Y) by
Andrei Alexandrescu for further background.

License: MIT
Author: Paul Backus
+/
module expectations;

/// $(H3 Basic Usage)
@safe unittest {
    import std.math: approxEqual;
    import std.exception: assertThrown;
    import std.algorithm: equal;

    Expected!double relative(double a, double b)
    {
        if (a == 0) {
            return unexpected!double(
                new Exception("Division by zero")
            );
        } else {
            return expected((b - a)/a);
        }
    }

    assert(relative(2, 3).hasValue);
    assert(relative(2, 3).value.approxEqual(0.5));

    assert(!relative(0, 1).hasValue);
    assertThrown(relative(0, 1).value);
    assert(relative(0, 1).exception.msg.equal("Division by zero"));
}

/**
 * An `Expected!T` is either a `T` or an exception explaining why the `T` couldn't
 * be produced.
 */
struct Expected(T)
	if (!is(T == Exception))
{
private:

	import sumtype;

	SumType!(T, Exception) data;

public:

	/**
	 * Constructs an `Expected!T` with a value.
	 *
	 * Not defined for `Expected!void`.
	 */
	this(T value)
	{
		data = value;
	}

	/**
	 * Constructs an `Expected!T` with an exception.
	 */
	this(Exception err)
	{
		data = err;
	}

	/**
	 * Assigns a value to an `Expected!T`.
	 *
	 * Not defined for `Expected!void`.
	 */
	void opAssign(T value)
	{
		data = value;
	}

	/**
	 * Assigns an exception to an `Expected!T`.
	 */
	void opAssign(Exception err)
	{
		data = err;
	}

	/**
	 * Checks whether this `Expected!T` contains a specific value.
	 *
	 * Not defined for `Expected!void`.
	 */
	bool opEquals(T rhs)
	{
		return data.match!(
			(T value) => value == rhs,
			(Exception _) => false
		);
	}

	/**
	 * Checks whether this `Expected!T` contains a specific exception.
	 */
	bool opEquals(Exception rhs)
	{
		return data.match!(
			(T _) => false,
			(Exception err) => err == rhs
		);
	}

	/**
	 * Checks whether this `Expected!T` and `rhs` contain the same value or
	 * exception.
	 */
	bool opEquals(Expected!T rhs)
	{
		return data.match!(
			(T value) => rhs == value,
			(Exception err) => rhs == err
		);
	}

	/**
	 * Checks whether this `Expected!T` contains a `T` value.
	 */
	bool hasValue()
	{
		return data.match!(
			(T _) => true,
			(Exception _) => false
		);
	}

	/**
	 * Returns the contained value if there is one. Otherwise, throws the
	 * contained exception.
	 */
	T value()
	{
		scope(failure) throw exception;
		return data.tryMatch!(
			(T value) => value,
		);
	}

	/**
	 * Returns the contained exception. May only be called when `hasValue`
	 * returns `false`.
	 */
	Exception exception()
		in(!hasValue)
	{
		scope(failure) assert(false);
		return data.tryMatch!(
			(Exception err) => err
		);
	}

	/**
	 * Returns the contained value if present, or a default value otherwise.
	 *
	 * Not defined for `Expected!void`.
	 */
	T valueOr(T defaultValue)
	{
		return data.match!(
			(T value) => value,
			(Exception _) => defaultValue
		);
	}
}

/// ditto
struct Expected(T : void)
{
private:

	import sumtype;

	struct Void {}

	SumType!(Void, Exception) data;

public:

	this(Exception err)
	{
		data = err;
	}

	void opAssign(Exception err)
	{
		data = err;
	}

	bool opEquals(Exception rhs)
	{
		return data.match!(
			(Void _) => false,
			(Exception err) => err == rhs
		);
	}

	bool opEquals(Expected!T rhs)
	{
		return data.match!(
			(Void _) => rhs.hasValue,
			(Exception err) => rhs == err
		);
	}

	bool hasValue()
	{
		return data.match!(
			(Void _) => true,
			(Exception _) => false
		);
	}

	T value()
	{
		scope(failure) throw exception;
		data.tryMatch!(
			(Void _) { return; },
		);
	}

	Exception exception()
		in(!hasValue)
	{
		scope(failure) assert(false);
		return data.tryMatch!(
			(Exception err) => err
		);
	}
}

// Construction
@safe nothrow unittest {
	assert(__traits(compiles, Expected!int(123)));
	assert(__traits(compiles, Expected!int(new Exception("oops"))));
}

// Assignment
@safe nothrow unittest {
	Expected!int x;

	assert(__traits(compiles, x = 123));
	assert(__traits(compiles, x = new Exception("oops")));
}

// Self assignment
@safe nothrow unittest {
	Expected!int x, y;

	assert(__traits(compiles, x = y));
}

// Equality with self
@system unittest {
	int n = 123;
	Exception e = new Exception("oops");

	Expected!int x = n;
	Expected!int y = n;
	Expected!int z = e;
	Expected!int w = e;

	assert(x == y);
	assert(z == w);
	assert(x != z);
	assert(z != x);
}

// Equality with T and Exception
@system unittest {
	int n = 123;
	Exception e = new Exception("oops");

	Expected!int x = n;
	Expected!int y = e;

	() @safe {
		assert(x == n);
		assert(y != n);
		assert(x != 456);
	}();

	assert(x != e);
	assert(y == e);
	assert(y != new Exception("oh no"));
}

// hasValue
@safe nothrow unittest {
	Expected!int x = 123;
	Expected!int y = new Exception("oops");

	assert(x.hasValue);
	assert(!y.hasValue);
}

// value
@system unittest {
	import std.exception: collectException;

	Exception e = new Exception("oops");

	Expected!int x = 123;
	Expected!int y = e;

	() @safe { assert(x.value == 123); }();
	assert(collectException(y.value) == e);
}

// exception
@system unittest {
	import std.exception: assertThrown;
	import core.exception: AssertError;

	Exception e = new Exception("oops");

	Expected!int x = 123;
	Expected!int y = e;

	assertThrown!AssertError(x.exception);
	assert(y.exception == e);
}

// valueOr
@safe nothrow unittest {
	Expected!int x = 123;
	Expected!int y = new Exception("oops");

	assert(x.valueOr(456) == 123);
	assert(y.valueOr(456) == 456);
}

// Expected!void: construction
@safe nothrow unittest {
	assert(__traits(compiles, Expected!void()));
	assert(__traits(compiles, Expected!void(new Exception("oops"))));
}

// Expected!void: assignment
@safe nothrow unittest {
	Expected!void x;

	assert(__traits(compiles, x = new Exception("oops")));
}

// Expected!void: self-assignment
@safe nothrow unittest {
	Expected!void x, y;

	assert(__traits(compiles, x = y));
}

// Expected!void: equality with self
@system unittest {
	Exception e = new Exception("oops");

	Expected!void x;
	Expected!void y;
	Expected!void z = e;
	Expected!void w = e;

	assert(x == y);
	assert(z == w);
	assert(x != z);
	assert(z != x);
}

// Expected!void: equality with Exception
@system unittest {
	Exception e = new Exception("oops");

	Expected!void x = e;

	assert(x == e);
	assert(x != new Exception("oh no"));
}

// Expected!void: hasValue
@safe nothrow unittest {
	Expected!void x;
	Expected!void y = new Exception("oops");

	assert(x.hasValue);
	assert(!y.hasValue);
}

// Expected!void: value
@system unittest {
	import std.exception: assertNotThrown, collectException;

	Exception e = new Exception("oops");

	Expected!void x;
	Expected!void y = e;

	() @safe { assertNotThrown(x.value); }();
	assert(collectException(y.value) == e);
}

// Expected!void: exception
@system unittest {
	import std.exception: assertThrown;
	import core.exception: AssertError;

	Exception e = new Exception("oops");

	Expected!void x;
	Expected!void y = e;

	assertThrown!AssertError(x.exception);
	assert(y.exception == e);
}

/**
 * Creates an `Expected` object from a value, with type inference.
 *
 * Not defined for `Expected!void`.
 */
Expected!T expected(T)(T value)
	if(!is(T == void))
{
	return Expected!T(value);
}

@safe nothrow unittest {
	assert(__traits(compiles, expected(123)));
	assert(is(typeof(expected(123)) == Expected!int));
}

/**
 * Creates an `Expected!void` object representing a successful outcome.
 */
Expected!T expected(T : void)()
{
	return Expected!void();
}

@safe nothrow unittest {
	assert(__traits(compiles, expected!void));
	assert(is(typeof({ return expected!void; }()) == Expected!void));
}

/**
 * Creates an `Expected` object from an exception.
 */
Expected!T unexpected(T)(Exception err)
{
	return Expected!T(err);
}

@safe nothrow unittest {
	Exception e = new Exception("oops");
	assert(__traits(compiles, unexpected!int(e)));
	assert(is(typeof(unexpected!int(e)) == Expected!int));
}
