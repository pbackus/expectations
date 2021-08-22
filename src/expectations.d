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
    import std.exception: assertThrown;

    Expected!int charToDigit(char c)
    {
        int d = c - '0';
        if (d >= 0 && d < 10) {
            return expected(d);
        } else {
            return missing!int(
                new Exception(c ~ " is not a valid digit")
            );
        }
    }

    auto goodResult = charToDigit('7');
    auto badResult = charToDigit('&');

    assert(goodResult.hasValue);
    assert(goodResult.value == 7);

    assert(!badResult.hasValue);
    assertThrown(badResult.value);
    assert(badResult.error.msg == "& is not a valid digit");
}

/**
 * An exception that represents an error value.
 */
class Unexpected(T) : Exception
{
	/**
	 * The error value.
	 */
	T value;

	/**
	 * Constructs an `Unexpected` exception from a value.
	 */
	pure @safe @nogc nothrow
	this(T value, string file = __FILE__, size_t line = __LINE__)
	{
		super("unexpected value", file, line);
		this.value = value;
	}
}

/**
 * An `Expected!(T, E)` contains either an expected value of type `T`, or an
 * error value of type `E` explaining why the expected value couldn't be
 * produced.
 *
 * The default type for the error value is `Exception`.
 *
 * A function that returns an `Expected` object has the following advantages
 * over one that may throw an exception or return an error code:
 *
 * $(LIST
 *   * It leaves the choice between manual error checking and automatic stack
 *     unwinding up to the caller.
 *   * It allows error handling to be deferred until the return value is
 *     actually needed (if ever).
 *   * It can be easily composed with other functions using [map] and
 *     [flatMap], which propagates error values automatically.
 *   * It can be used in `nothrow` code.
 * )
 *
 * An `Expected!(T, E)` is initialized by default to contain the value `T.init`.
 *
 * $(PITFALL Unlike a thrown exception, an error returned via an `Expected`
 * object will be silently ignored if the function's return value is discarded.
 * For best results, functions that return `Expected` objects should be marked
 * as `pure`, so that the D compiler will warn about discarded return values.)
 */
struct Expected(T, E = Exception)
	if (!is(T == E) && !is(T == void))
{
private:

	import sumtype;

	SumType!(T, E) data;

public:

	/**
	 * Constructs an `Expected` object that contains an expected value.
	 */
	this(T value)
	{
		data = value;
	}

	/**
	 * Constructs an `Expected` object that contains an error value.
	 */
	this(E err)
	{
		data = err;
	}

	/**
	 * Assigns an expected value to an `Expected` object.
	 */
	void opAssign(T value)
	{
		data = value;
	}

	/**
	 * Assigns an error value to an `Expected` object.
	 */
	void opAssign(E err)
	{
		data = err;
	}

	/**
	 * Checks whether this `Expected` object contains a specific expected value.
	 */
	bool opEquals(T rhs)
	{
		return data.match!(
			(T value) => value == rhs,
			(E _) => false
		);
	}

	/**
	 * Checks whether this `Expected` object contains a specific error value.
	 */
	bool opEquals(E rhs)
	{
		return data.match!(
			(T _) => false,
			(E err) => err == rhs
		);
	}

	/**
	 * Checks whether this `Expected` object and `rhs` contain the same expected
	 * value or error value.
	 */
	bool opEquals(Expected!(T, E) rhs)
	{
		return data.match!(
			(T value) => rhs == value,
			(E err) => rhs == err
		);
	}

	/**
	 * Checks whether this `Expected` object contains an expected value or an
	 * error value.
	 */
	bool hasValue() const
	{
		return data.match!(
			(const T _) => true,
			(const E _) => false
		);
	}

	/**
	 * Returns the expected value if there is one. Otherwise, throws an
	 * exception
	 *
	 * Throws:
	 *   If `E` inherits from `Throwable`, the error value is thrown.
	 *   Otherwise, an [Unexpected] instance containing the error value is
	 *   thrown.
	 */
	inout(T) value() inout
	{
		return data.match!(
			(inout(T) value) => value,
			delegate T (inout(E) err) {
				static if(is(E : Throwable)) {
					throw error;
				} else {
					throw new Unexpected!E(error);
				}
			}
		);
	}

	/**
	 * Returns the error value. May only be called when `hasValue` returns
	 * `false`.
	 */
	inout(E) error() inout
		in { assert(!hasValue); }
	do {
		import std.exception: assumeWontThrow;

		return data.tryMatch!(
			(inout(E) err) => err
		).assumeWontThrow;
	}

	deprecated("Renamed to `error`")
	inout(E) exception() inout
	{
		return error;
	}

	/**
	 * Returns the expected value if present, or a default value otherwise.
	 */
	inout(T) valueOr(inout(T) defaultValue) inout
	{
		return data.match!(
			(inout(T) value) => value,
			(inout(E) _) => defaultValue
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

	Expected!int x = 123;
	Expected!int y = new Exception("oops");

	assert(x.value == 123);
	assert(collectException(y.value).msg == "oops");
}

// error
@system unittest {
	Exception e = new Exception("oops");
	Expected!int x = e;

	assert(x.error == e);
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
	const(Expected!int) x = 123;
	const(Expected!int) y = new Exception("oops");

	// hasValue
	assert(x.hasValue);
	assert(!y.hasValue);
	// value
	assert(x.value == 123);
	// error
	assert(y.error.msg == "oops");
	// valueOr
	assert(x.valueOr(456) == 123);
	assert(y.valueOr(456) == 456);
}

// Explicit error type
@safe unittest {
	import std.exception: assertThrown;

	Expected!(int, string) x = 123;
	Expected!(int, string) y = "oops";

	// haValue
	assert(x.hasValue);
	assert(!y.hasValue);
	// value
	assert(x.value == 123);
	assertThrown!(Unexpected!string)(y.value);
	// error
	assert(y.error == "oops");
	// valueOr
	assert(x.valueOr(456) == 123);
	assert(y.valueOr(456) == 456);
}

/**
 * Creates an `Expected` object from an expected value, with type inference.
 */
Expected!(T, E) expected(T, E = Exception)(T value)
{
	return Expected!(T, E)(value);
}

// Default error type
@safe nothrow unittest {
	assert(__traits(compiles, expected(123)));
	assert(is(typeof(expected(123)) == Expected!int));
}

// Explicit error type
@safe nothrow unittest {
	assert(__traits(compiles, expected!(int, string)(123)));
	assert(is(typeof(expected!(int, string)(123)) == Expected!(int, string)));
}

/**
 * Creates an `Expected` object from an error value.
 */
Expected!(T, E) missing(T, E)(E err)
{
	return Expected!(T, E)(err);
}

@safe nothrow unittest {
	Exception e = new Exception("oops");
	assert(__traits(compiles, missing!int(e)));
	assert(is(typeof(missing!int(e)) == Expected!int));
}

@safe nothrow unittest {
	auto x = missing!int("oops");
	assert(__traits(compiles, missing!int("oops")));
	assert(is(typeof(missing!int("oops")) == Expected!(int, string)));
}

deprecated("Renamed to `missing`")
Expected!(T, E) unexpected(T, E)(E err)
{
	return missing!T(err);
}

/**
 * Applies a function to the expected value in an `Expected` object.
 *
 * If no expected value is present, the original error value is passed through
 * unchanged, and the function is not called.
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
	auto map(T, E)(Expected!(T, E) self)
		if (is(typeof(fun(self.value))))
	{
		import sumtype: match;

		alias U = typeof(fun(self.value));

		return self.data.match!(
			(T value) => expected!(U, E)(fun(value)),
			(E err) => missing!U(err)
		);
	}
}

@safe unittest {
	import std.math: isClose;

	Expected!int x = 123;
	Expected!int y = new Exception("oops");

	double half(int n) { return n / 2.0; }

	assert(__traits(compiles, () nothrow {
		x.map!half;
	}));

	assert(x.map!half.value.isClose(61.5));
	assert(y.map!half.error.msg == "oops");

	alias mapHalf = map!half;

	assert(mapHalf(Expected!int(123)).value.isClose(61.5));
}

@safe unittest {
	Expected!(int, string) x = 123;
	Expected!(int, string) y = "oops";

	assert(x.map!(n => n*2).value == 246);
	assert(y.map!(n => n*2).error == "oops");
}

/**
 * Forwards the expected value in an `Expected` object to a function that
 * returns an `Expected` result.
 *
 * If the original `Expected` object contains an error value, it is passed
 * through to the result, and the function is not called.
 *
 * Returns:
 *   The `Expected` object returned from the function, or an `Expected` object
 *   of the same type containing the original error value.
 */
template flatMap(alias fun)
{
	/**
	 * The actual `flatMap` function.
	 *
	 * Params:
	 *   self = an [Expected] object
	 */
	auto flatMap(T, E1)(Expected!(T, E1) self)
		if (is(typeof(fun(self.value)) == Expected!(U, E2), U, E2)
		    && is(E1 : E2))
	{
		import sumtype: match;

		alias ExpectedUE2 = typeof(fun(self.value));
		alias E2 = typeof(ExpectedUE2.init.error());

		return self.data.match!(
			(T value) => fun(value),
			(E1 err) => ExpectedUE2(cast(E2) err)
		);
	}
}

@safe unittest {
	import std.math: isClose;

	Expected!int x = 123;
	Expected!int y = 0;
	Expected!int z = new Exception("oops");

	Expected!double recip(int n)
	{
		if (n == 0) {
			return missing!double(new Exception("Division by zero"));
		} else {
			return expected(1.0 / n);
		}
	}

	assert(__traits(compiles, () nothrow {
		x.flatMap!recip;
	}));

	assert(x.flatMap!recip.value.isClose(1.0/123));
	assert(y.flatMap!recip.error.msg == "Division by zero");
	assert(z.flatMap!recip.error.msg == "oops");

	alias flatMapRecip = flatMap!recip;

	assert(flatMapRecip(Expected!int(123)).value.isClose(1.0/123));
}

@safe unittest {
	import std.math: isClose;

	Expected!(int, string) x = 123;
	Expected!(int, string) y = 0;
	Expected!(int, string) z = "oops";

	Expected!(double, string) recip(int n)
	{
		if (n == 0) {
			return missing!double("Division by zero");
		} else {
			return expected!(double, string)(1.0 / n);
		}
	}

	assert(__traits(compiles, () nothrow {
		x.flatMap!recip;
	}));

	assert(x.flatMap!recip.value.isClose(1.0/123));
	assert(y.flatMap!recip.error == "Division by zero");
	assert(z.flatMap!recip.error == "oops");
}

deprecated("Renamed to `flatMap`")
template andThen(alias fun)
{
	alias andThen = flatMap!fun;
}
