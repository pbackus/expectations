expected
========

A wrapper type that bundles exceptions with return values

Documentation
-------------

[View online on Github Pages.][docs]

`expected` uses [adrdox][] to generate its documentation. To build your own
copy, run the following command from the root of the `sumtype` repository:

    path/to/adrdox/doc2 --genSearchIndex --genSource -o generated-docs src

[docs]: https://pbackus.github.io/expected/expected.html
[adrdox]: https://github.com/adamdruppe/adrdox

Example
-------

    import std.math: approxEqual;

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

    assert(relative(2.0, 3.0).value.approxEqual(0.5));
    assert(relative(0.0, 1.0).hasValue == false);
