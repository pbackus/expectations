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

Installation
------------

If you're using dub, add the
[expectations](https://code.dlang.org/packages/expectations) package to your
project as a dependency.

Otherwise, you will need to add both `expectations.d` and its dependency
`sumtype.d` (from the [sumtype](https://github.com/pbackus/sumtype) package) to
your source directory.
