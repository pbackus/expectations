expectations
============

Error handling that bundles exceptions with return values

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
