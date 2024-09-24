# XpressAPI - A module for low-level access to the Xpress C API

This package/module provides access to the Xpress C functions from Julia.
While (in theory) any C function can be directly accessed from Julia, this is
sometimes cumbersome and errorprone since for every call you have to know and
specify the exact prototype of the C function, have to jump through some hoops
for handling output arguments, have to perform error checking, etc.

The goal of this module is to simplify this as much as possible. As a
consequence, the module provides a Julia function/method wrapper for every
C function.

The goal of this module is *not* to provide a full-fledged Julia API or even
a modeling API. These things can be built on top of this module.

A minimal code example for using this module is here:
```
using XpressAPI

XPRScreateprob("") do prob
  XPRSaddcbmessage(prob, (p, m, l, t) -> if t > 0 println(l > 0 ? "" : m); end, 0)
  XPRSreadprob(prob, "afiro.mps", "")
  XPRSlpoptimize(prob, "")
  println(XPRSgetdblattrib(prob, XPRS_LPOBJVAL))
end

```

## Installation

XpressAPI does not provide Xpress binaries, a proper Xpress installion is needed to use this package.
Please visit https://community.fico.com/s/optimization for further details.
Ensure that the `XPRESSDIR` license variable is set to the install location by
checking the output of:
```julia
julia> ENV["XPRESSDIR"]
```

Then, install this package using:
```julia
import Pkg
Pkg.add("https://github.com/fico-xpress/XpressAPI.jl.git")
```

## License handling

Before any Xpress function can be used, a license must be acquired. There
are several ways to acquire a license. The most common way probably is to
acquire a license along with the creation of a problem:
```
XPRScreateprob("") do prob
  ...
end
```
If `XPRScreateprob` is passed a string, then it calls `XPRSinit` with that
string in order to acquire a license. That license is automatically released
when the problem is destroyed.

You can call `XPRScreateprob` with an argument of `nothing` to prevent the
function from calling `XPRSinit`.

A license can also be explicitly initialized by calling `XPRSinit`:
```
XPRSinit("") do lic
  ...
end
```
This is useful in case you need to create many problems (otherwise calling
`XPRSinit` for every problem may incur some overhead) or if you want to
explicitly control the lifetime of the license.

## Function mapping

As stated above, this module provides a Julia wrapper for (almost) every
function in the Xpress solver's C API.

Most of the parameters are mapped 1:1 between Julia and C. However, there are
a few exceptions:
- The integer error code returned by every library function is checked in the
  module and translated into an `XPRSexception` in case it is non-zero.
- Output parameters are translated into (multiple) return values.
- In case a function that operates on an `XPRSprob` has no output parameters,
  it returns the `XPRSprob` that was passed to it. This allows these functions
  to be chained/piped.

Note that functions `XPRSfree()`, `XPRSdestroyprob()` `XPRS_bo_destroy()`
have no wrappers. Instead there is a `close()` function for the respective
objects. That function is also setup as the object's finalizer, so usually you
should not need to bother with that `close()` function.

A number of functions fill an array and return that filled array. These
functions allow passing either an array to be filled or the special value
`XPRS_ALLOC`. In case `XPRS_ALLOC` is passed, the function will allocate the
array for you. For example, you can call `XPRSgetrhs` in two ways:
- With an explicitly allocated array:
```
rhs = Vector{Float64}(undef, 5)
rhs = XPRSgetrhs(prob, rhs, 0, 4)
```
- Have the function allocate the appropriate array for you:
```
rhs = XPRSgetrhs(prob, XPRS_ALLOC, 0, 4)
```

## Array indices

Entities in the Xpress API are numbered starting from 0. For example, columns
in a model are numbered from 0 to number of columns - 1.
On the other hand, Julia arrays start with an index of 1, don't be confused
by that.

## Callbacks

Callback functions can be any callable objects (top-level functions, local
functions, closures, ...).

Callbacks undergo the same argument translation as regular functions, i.e.,
output parameters become return values. Note that some callbacks have inout
parameters, so these will appear as parameter and will also be excepted as
return values.

If a callback raises an exception then the following happens:
- The exception is captured.
- The solution process is interrupted via `XPRSinterrupt(XPRS_STOP_GENERICERROR)`.
- Once the optimizing C function returns to Julia, the exception that was
  captured before is thrown (wrapped into a new `XPRSexception` instance).

## Error handling

Errors from calling the low-level C functions are translated into exceptions.
The exception that is thrown by the functions in this module is `XPRSexception`.
Note that not only library errors may trigger this exception. Another typical
situation in which this exception may be raised is when buffers are detected to
be not long enough.
