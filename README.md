# XpressAPI - A module for low-level access to the Xpress C API


This package provides access from Julia to Xpress Solver C functions. While (in theory) 
any C function can be directly accessed from Julia, this is sometimes cumbersome and error-prone 
since for every call you must know and specify the exact prototype of the C function. 
Consequently, this package provides a Julia function wrapper for every C function.

The goal of this package is *not* to provide a full-fledged Julia API or even
a modeling API. These things can be built on top of this package.

## Installation

XpressAPI does not provide Xpress Solver binaries. If you do not have any recent installation 
of FICO Xpress, download the free [Xpress Community Edition](https://www.fico.com/en/fico-xpress-community-license) after creating a user account. By 
downloading, you agree to the Community License terms of the [Xpress Shrinkwrap License Agreement](https://community.fico.com/s/contentdocument/06980000002h0i5AAA). 
See the [licensing options overview](https://community.fico.com/s/fico-xpress-optimization-licensing-optio) for additional details and information about obtaining a paid license.

Ensure that the `XPRESSDIR` license variable is set to the install location by
checking the output of:
```julia
julia> ENV["XPRESSDIR"]
```

Then, install this package using:
```julia
import Pkg
Pkg.add("XpressAPI")
```

A minimal code example for using this package:
```julia
using XpressAPI

XPRScreateprob("") do prob
  XPRSaddcbmessage(prob, (p, m, l, t) -> if t > 0 println(l > 0 ? "" : m); end, 0)
  XPRSreadprob(prob, "afiro.mps", "")
  XPRSlpoptimize(prob, "")
  println(XPRSgetdblattrib(prob, XPRS_LPOBJVAL))
end
```

### Detailed Feature List

See [MOI_FEATURES.md](MOI_FEATURES.md) for a comprehensive list of:
- Supported constraint types with examples
- Callback usage patterns
- Solution status codes
- Modification operations
- Performance considerations

## Use with Xpress_jll

Instead of manually installing Xpress, you can use the binaries provided by the
[Xpress_jll.jl](https://github.com/jump-dev/Xpress_jll.jl) package.

By using Xpress_jll, you agree to certain license conditions. See the
[Xpress_jll.jl README](https://github.com/jump-dev/Xpress_jll.jl/tree/master?tab=readme-ov-file#license)
for more details.

```julia
import Xpress_jll
# This environment variable must be set _before_ loading Xpress.jl
ENV["XPRESS_JL_LIBRARY"] = Xpress_jll.libxprs
# Point to your xpauth.xpr license file
ENV["XPAUTH_PATH"] = "/path/to/xpauth.xpr"
using XpressAPI
```

## License handling

Before any Xpress function can be used, a license must be initialized. There
are several ways to acquire a license. The most common way probably is to
acquire a license along with the creation of a problem:
```julia
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
```julia
XPRSinit("") do lic
  ...
end
```
This is useful in case you need to create many problems (otherwise calling
`XPRSinit` for every problem may incur some overhead) or if you want to
explicitly control the lifetime of the license.

## Function mapping

As stated above, this package provides a Julia wrapper for (almost) every
function in the Xpress solver's C API.

Most of the parameters are mapped 1:1 between Julia and C. However, there are
a few exceptions:
- The integer error code returned by every library function is checked in the
  package and translated into an `XPRSexception` in case it is non-zero.
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
```julia
rhs = Vector{Float64}(undef, 5)
rhs = XPRSgetrhs(prob, rhs, 0, 4)
```
- Have the function allocate the appropriate array for you:
```julia
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
The exception that is thrown by the functions in this package is `XPRSexception`.
Note that not only library errors may trigger this exception. Another typical
situation in which this exception may be raised is when buffers are detected to
be not long enough.

---
# JuMP Integration

XpressAPI provides a **comprehensive MathOptInterface (MOI) extension** that enables high-level optimization modeling through [JuMP](https://jump.dev). The MOI interface is an external deps of XpressAPI and loads automatically when MathOptInterface is available.

### Quick Start with JuMP

```julia
using JuMP, XpressAPI

model = Model(XpressAPI.Optimizer)
set_silent(model)  # Suppress solver output

@variable(model, x >= 0)
@variable(model, y >= 0)
@variable(model, z, Bin)  # Binary variable

@constraint(model, 2x + 3y <= 10)
@constraint(model, x^2 + y^2 <= 25)  # Quadratic constraint

@objective(model, Min, x^2 + 2y^2 + x + y)

optimize!(model)

if termination_status(model) == OPTIMAL
    println("x = ", value(x))
    println("y = ", value(y))
    println("Objective = ", objective_value(model))
end
```

---
## Variable Types

XpressAPI supports all standard MOI variable types through `MOI.VariableIndex` constraints:

### Supported Variable Types

| Variable Type | MOI Set | Description |
|--------------|---------|-------------|
| **Continuous** | *none* | Default variable type (unbounded) |
| **Binary** | `MOI.ZeroOne` | Binary variable ∈ {0, 1} |
| **Integer** | `MOI.Integer` | General integer variable |
| **Semicontinuous** | `MOI.Semicontinuous` | Variable is either 0 or in [lb, ub] |
| **Semiinteger** | `MOI.Semiinteger` | Integer variable is either 0 or in {lb, ..., ub} |

### Variable Bounds

| Bound Type | MOI Set | Constraint Type |
|-----------|---------|-----------------|
| **Lower bound** | `MOI.GreaterThan{Float64}` | `x ≥ lb` |
| **Upper bound** | `MOI.LessThan{Float64}` | `x ≤ ub` |
| **Fixed value** | `MOI.EqualTo{Float64}` | `x == value` |
| **Interval** | `MOI.Interval{Float64}` | `lb ≤ x ≤ ub` |

**Note**: `MOI.Interval` constraints are reformulated as separate upper and lower bounds internally.

---
## Constraint Types

### Linear Constraints

#### Linear Constraints

| Function | Set | Form |
|----------|-----|------|
| `MOI.ScalarAffineFunction{Float64}` | `MOI.LessThan{Float64}` | `aᵀx ≤ b` |
| `MOI.ScalarAffineFunction{Float64}` | `MOI.GreaterThan{Float64}` | `aᵀx ≥ b` |
| `MOI.ScalarAffineFunction{Float64}` | `MOI.EqualTo{Float64}` | `aᵀx == b` |

### Quadratic Constraints

| Function | Set | Form |
|----------|-----|------|
| `MOI.ScalarQuadraticFunction{Float64}` | `MOI.LessThan{Float64}` | `½xᵀQx + aᵀx ≤ b` |
| `MOI.ScalarQuadraticFunction{Float64}` | `MOI.GreaterThan{Float64}` | `½xᵀQx + aᵀx ≥ b` |
| `MOI.ScalarQuadraticFunction{Float64}` | `MOI.EqualTo{Float64}` | `½xᵀQx + aᵀx == b` |

**Note**: Xpress supports both convex and non-convex quadratic constraints.

### Nonlinear Constraints

General nonlinear constraints using Xpress's native NLP solver:

| Function | Set | Form |
|----------|-----|------|
| `MOI.ScalarNonlinearFunction` | `MOI.LessThan{Float64}` | `f(x) ≤ b` |
| `MOI.ScalarNonlinearFunction` | `MOI.GreaterThan{Float64}` | `f(x) ≥ b` |
| `MOI.ScalarNonlinearFunction` | `MOI.EqualTo{Float64}` | `f(x) == b` |

**Supported Nonlinear Operators**:
- Standard operators: `+`, `-`, `*`, `/`, `^`
- Transcendental functions: `exp`, `log` (ln), `log10`, `sqrt`
- Trigonometric: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`
- Statistical (SpecialFunctions.jl): `erf` (error function), `erfc` (complementary error function)
- Other: `abs`, `min`, `max`

**Custom User-Defined Operators**: Supports JuMP's `@operator` macro for user-defined functions with provided derivatives.

### Indicator Constraints

Constraints that are only active when a binary variable takes a specific value:

**Supported Forms**:
- **ACTIVATE_ON_ONE**: `z == 1 ⟹ constraint`
- **ACTIVATE_ON_ZERO**: `z == 0 ⟹ constraint`

| Function | Set | Description |
|----------|-----|-------------|
| `MOI.VectorAffineFunction` | `MOI.Indicator{MOI.ACTIVATE_ON_ONE, S}` | Linear indicator |
| `MOI.VectorQuadraticFunction` | `MOI.Indicator{MOI.ACTIVATE_ON_ONE, S}` | Quadratic indicator |
| `MOI.VectorNonlinearFunction` | `MOI.Indicator{MOI.ACTIVATE_ON_ONE, S}` | Nonlinear indicator |
| `MOI.VectorAffineFunction` | `MOI.Indicator{MOI.ACTIVATE_ON_ZERO, S}` | Linear indicator |
| `MOI.VectorQuadraticFunction` | `MOI.Indicator{MOI.ACTIVATE_ON_ZERO, S}` | Quadratic indicator |
| `MOI.VectorNonlinearFunction` | `MOI.Indicator{MOI.ACTIVATE_ON_ZERO, S}` | Nonlinear indicator |

Where `S` can be `MOI.LessThan`, `MOI.GreaterThan`, or `MOI.EqualTo`.

### Special Ordered Sets (SOS)

| Function | Set | Description |
|----------|-----|-------------|
| `MOI.VectorOfVariables` | `MOI.SOS1{Float64}` | At most one variable in the set can be non-zero |
| `MOI.VectorOfVariables` | `MOI.SOS2{Float64}` | At most two consecutive variables can be non-zero |

---
## Objective Functions

### Supported Objective Types

| Objective Function Type | Description |
|------------------------|-------------|
| `MOI.VariableIndex` | Single variable objective: `min/max x` |
| `MOI.ScalarAffineFunction{Float64}` | Linear objective: `min/max aᵀx + b` |
| `MOI.ScalarQuadraticFunction{Float64}` | Quadratic objective: `min/max ½xᵀQx + aᵀx + b` |
| `MOI.ScalarNonlinearFunction` | Nonlinear objective: `min/max f(x)` (via slack bridge) |
| `MOI.VectorOfVariables` | Multi-objective: Native support for multiple objectives |

### Raw Optimizer Attributes

Access any Xpress control or attribute directly:

```julia
MOI.set(model, MOI.RawOptimizerAttribute("PRESOLVE"), 0)  # Disable presolve
gap = MOI.get(model, MOI.RawOptimizerAttribute("MIPRELGAP"))  # Get MIP gap
```

**All Xpress controls and attributes** are accessible via `MOI.RawOptimizerAttribute`.

---
## Callbacks

XpressAPI supports MOI callbacks for customizing the branch-and-bound process:

### Supported Callbacks

| Callback Type | MOI Type | Description | When Called |
|--------------|----------|-------------|-------------|
| **User Cuts** | `MOI.UserCutCallback` | Add cutting planes | At fractional LP solutions |

---
## Conflict Analysis (IIS)

### Irreducible Inconsistent Subsystem (IIS)

XpressAPI supports computing IIS for infeasible models:

```julia
using JuMP, XpressAPI

model = Model(XpressAPI.Optimizer)
@variable(model, x)
@constraint(model, c1, x >= 1)
@constraint(model, c2, x <= 0)
optimize!(model)

# Compute IIS
MOI.compute_conflict!(model)

# Check conflict status
status = MOI.get(model, MOI.ConflictStatus())  # Returns MOI.CONFLICT_FOUND

# Check which constraints are in IIS
c1_status = MOI.get(model, MOI.ConstraintConflictStatus(), c1)
# Returns MOI.IN_CONFLICT if c1 is in the IIS
```

**Conflict Status Codes**:
- `MOI.CONFLICT_FOUND` - IIS successfully computed
- `MOI.NO_CONFLICT_EXISTS` - Model is feasible
- `MOI.NO_CONFLICT_FOUND` - Could not find IIS
- `MOI.COMPUTE_CONFLICT_NOT_CALLED` - IIS computation not performed

**Constraint Conflict Status**:
- `MOI.IN_CONFLICT` - Constraint is in the IIS
- `MOI.NOT_IN_CONFLICT` - Constraint is not in the IIS
- `MOI.MAYBE_IN_CONFLICT` - Status unknown

---

## Bridges

### Custom Objective Bridge

XpressAPI provides a **custom objective slack bridge** (`StrictObjectiveSlackBridge`) that reformulates non-native objective types:

**Transformation**:
```
min/max F(x)
```
becomes:
```
min/max c
s.t. F(x) - c == 0
```

This bridge enables Xpress to solve problems with objective functions that would otherwise require reformulation.

**Automatically applied for**:
- Nonlinear objectives (`MOI.ScalarNonlinearFunction`)
- Any other objective function type not natively supported by Xpress

### MOI Bridge Support

XpressAPI works seamlessly with MOI's automatic bridging system, which can transform:
- Conic constraints → Quadratic constraints (e.g., `MOI.SecondOrderCone`)
- Interval constraints → Separate bounds
- And many more transformations

To use bridges with XpressAPI:
```julia
using JuMP, XpressAPI
model = Model(() -> MOI.Bridges.full_bridge_optimizer(XpressAPI.Optimizer(), Float64))
```