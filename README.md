expected
========

A wrapper type that bundles exceptions with return values

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
