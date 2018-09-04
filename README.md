expectations
============

Error handling that bundles exceptions with return values.

Features
--------

- `Expected` values can be treated like return codes or exceptions:
    - Use `hasValue` to check for success or failure explicitly.
    - Use `value` directly to assume success and throw in case of failure.
- Error handling is deferred until the value is actually needed.
- Functions that return `Expected` values can be composed easily using
  `andThen` and `map`.
- Usable in `@safe` and `nothrow` code.

Documentation
-------------

[View online on Github Pages.][docs]

`expectations` uses [adrdox][] to generate its documentation. To build your own
copy, run the following command from the root of the `sumtype` repository:

    path/to/adrdox/doc2 --genSearchIndex --genSource -o generated-docs src

[docs]: https://pbackus.github.io/expectations/expectations.html
[adrdox]: https://github.com/adamdruppe/adrdox

Example
-------

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

Installation
------------

If you're using dub, add the
[expectations](https://code.dlang.org/packages/expectations) package to your
project as a dependency.

Otherwise, you will need to add both `expectations.d` and `sumtype.d` (from
[sumtype](https://github.com/pbackus/sumtype)) to your source directory.
