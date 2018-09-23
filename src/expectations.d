/++
Error handling that bundles exceptions with return values.

The design of this module is based on C++'s proposed
[std::expected](https://wg21.link/p0323) and Rust's
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
 * An `Expected!T` is either a value of type `T` or an exception explaining why
 * the value couldn't be produced.
 *
 * Instead of either returning a value or throwing an exception, a function
 * that may fail can return an `Expected` object containing either the value
 * it would normally have returned, or the exception it would have thrown.
 *
 * A function that returns an `Expected` object has the following advantages
 * over one that either returns a value or throws an exception:
 *
 * $(LIST
 *   * It leaves the choice between manual error checking and automatic stack
 *     unwinding up to the caller.
 *   * It allows error handling to be deferred until the return value is
 *     actually needed.
 *   * It can be easily composed with other functions using [map] and
 *     [andThen], which propagate exceptions automatically.
 *   * It can be used in `nothrow` code.
 * )
 *
 * An `Expected!T` is initialized by default to contain the value `T.init`.
 *
 * $(WARNING Because `Expected` uses the presence or absence of a value to
 * distinguish between success and failure, it should not be used by functions
 * that may return a value when they fail, or that may fail to return a value
 * when they succeed.)
 */
struct Expected(T)
	if (!is(T == Exception) && !is(T == void))
{
private:

	import sumtype;

	SumType!(T, Exception) data;

public:

	/**
	 * Constructs an `Expected!T` that contains a value.
	 */
	this(T value)
	{
		data = value;
	}

	/**
	 * Constructs an `Expected!T` that contains an exception.
	 */
	this(Exception err)
	{
		data = err;
	}

	/**
	 * Assigns a value to an `Expected!T`.
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
	 * Checks whether this `Expected!T` contains a value or an exception.
	 */
	bool hasValue() const
	{
		return data.match!(
			(const T _) => true,
			(const Exception _) => false
		);
	}

	/**
	 * Returns the contained value if there is one. Otherwise, throws the
	 * contained exception.
	 */
	inout(T) value() inout
	{
		scope(failure) throw exception;
		return data.tryMatch!(
			(inout(T) value) => value,
		);
	}

	/**
	 * Returns the contained exception. May only be called when `hasValue`
	 * returns `false`.
	 */
	inout(Exception) exception() inout
		in(!hasValue)
	{
		import std.exception: assumeWontThrow;

		return data.tryMatch!(
			(inout(Exception) err) => err
		).assumeWontThrow;
	}

	/**
	 * Returns the contained value if present, or a default value otherwise.
	 */
	inout(T) valueOr(inout(T) defaultValue) inout
	{
		return data.match!(
			(inout(T) value) => value,
			(inout(Exception) _) => defaultValue
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
@safe unittest {
	import std.exception: collectException;
	import std.algorithm: equal;

	Expected!int x = 123;
	Expected!int y = new Exception("oops");

	assert(x.value == 123);
	assert(collectException(y.value).msg.equal("oops"));
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

// const(Expected)
@safe unittest {
	import std.algorithm: equal;

	const(Expected!int) x = 123;
	const(Expected!int) y = new Exception("oops");

	// hasValue
	assert(x.hasValue);
	assert(!y.hasValue);
	// value
	assert(x.value == 123);
	// exception
	assert(y.exception.msg.equal("oops"));
	// valueOr
	assert(x.valueOr(456) == 123);
	assert(y.valueOr(456) == 456);
}

/**
 * Creates an `Expected` object from a value, with type inference.
 */
Expected!T expected(T)(T value)
{
	return Expected!T(value);
}

@safe nothrow unittest {
	assert(__traits(compiles, expected(123)));
	assert(is(typeof(expected(123)) == Expected!int));
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

/**
 * Applies a function to the value in an `Expected!T`.
 *
 * If no value is present, the original exception is passed through unchanged.
 *
 * Returns:
 *   A new `Expected` object containing the result.
 */
template map(alias fun)
{
	/**
	 * The actual `map` function.
	 *
	 * Params:
	 *   self = an [Expected] object.
	 */
	auto map(T)(Expected!T self)
		if (is(typeof(fun(self.value))))
	{
		import sumtype: match;

		alias U = typeof(fun(self.value));

		return self.data.match!(
			(T value) => expected(fun(value)),
			(Exception err) => unexpected!U(err)
		);
	}
}

@safe unittest {
	import std.math: approxEqual;
	import std.algorithm: equal;

	Expected!int x = 123;
	Expected!int y = new Exception("oops");

	double half(int n) { return n / 2.0; }

	assert(__traits(compiles, () nothrow {
		x.map!half;
	}));

	assert(x.map!half.value.approxEqual(61.5));
	assert(y.map!half.exception.msg.equal("oops"));

	alias mapHalf = map!half;

	assert(mapHalf(Expected!int(123)).value.approxEqual(61.5));
}

/**
 * Forwards the value in an `Expected!T` to a function that returns an
 * `Expected` result.
 *
 * If no value is present, the original exception is passed through unchanged.
 *
 * Returns:
 *   The `Expected` object returned from the function, or an `Expected` object
 *   of the same type containing the original exception.
 */
template andThen(alias fun)
{
	/**
	 * The actual `andThen` function.
	 *
	 * Params:
	 *   self = an [Expected] object
	 */
	auto andThen(T)(Expected!T self)
		if (is(typeof(fun(self.value)) : Expected!U, U))
	{
		import sumtype: match;

		alias ExpectedU = typeof(fun(self.value));

		return self.data.match!(
			(T value) => fun(value),
			(Exception err) => ExpectedU(err)
		);
	}
}

@safe unittest {
	import std.math: approxEqual;
	import std.algorithm: equal;

	Expected!int x = 123;
	Expected!int y = 0;
	Expected!int z = new Exception("oops");

	Expected!double recip(int n)
	{
		if (n == 0) {
			return unexpected!double(new Exception("Division by zero"));
		} else {
			return expected(1.0 / n);
		}
	}

	assert(__traits(compiles, () nothrow {
		x.andThen!recip;
	}));

	assert(x.andThen!recip.value.approxEqual(1.0/123));
	assert(y.andThen!recip.exception.msg.equal("Division by zero"));
	assert(z.andThen!recip.exception.msg.equal("oops"));

	alias andThenRecip = andThen!recip;

	assert(andThenRecip(Expected!int(123)).value.approxEqual(1.0/123));
}
