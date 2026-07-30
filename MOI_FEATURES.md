# XpressAPI.jl - JuMP/MOI Interface Features

This document describes the MathOptInterface (MOI) capabilities of XpressAPI.jl, which enables JuMP integration for the Xpress Optimizer.

---

## Overview

XpressAPI.jl provides a **comprehensive MOI extension** (`XpressMOIExt`) that enables high-level optimization modeling through JuMP. The MOI interface is implemented as a **weak dependency** that only loads when MathOptInterface is available, keeping the base package lightweight for users who only need the low-level C API.

**Implementation** across 7 modular files:
- `MOI_common.jl` - Core optimizer and infrastructure
- `MOI_linear.jl` - Linear constraints and objectives
- `MOI_nonlinear.jl` - Nonlinear optimization support
- `MOI_bridges.jl` - Custom objective bridges
- `MOI_quadratic.jl` - Quadratic constraints and objectives
- `MOI_indicator.jl` - Indicator (implication) constraints
- `MOI_callbacks.jl` - Callback support for branch-and-bound

---

## Variable Types

XpressAPI supports all standard MOI variable types through `MOI.VariableIndex` constraints:

### ✅ Supported Variable Types

| Variable Type | MOI Set | Description |
|--------------|---------|-------------|
| **Continuous** | *none* | Default variable type (unbounded) |
| **Binary** | `MOI.ZeroOne` | Binary variable ∈ {0, 1} |
| **Integer** | `MOI.Integer` | General integer variable |
| **Semicontinuous** | `MOI.Semicontinuous` | Variable is either 0 or in [lb, ub] |
| **Semiinteger** | `MOI.Semiinteger` | Integer variable is either 0 or in {lb, ..., ub} |

### ✅ Variable Bounds

| Bound Type | MOI Set | Constraint Type |
|-----------|---------|-----------------|
| **Lower bound** | `MOI.GreaterThan{Float64}` | `x ≥ lb` |
| **Upper bound** | `MOI.LessThan{Float64}` | `x ≤ ub` |
| **Fixed value** | `MOI.EqualTo{Float64}` | `x == value` |
| **Interval** | `MOI.Interval{Float64}` | `lb ≤ x ≤ ub` |

**Note**: `MOI.Interval` constraints are reformulated as separate upper and lower bounds internally.

---

## Constraint Types

### ✅ Linear Constraints

#### Scalar Linear Constraints
Constraints of the form: `a₁x₁ + a₂x₂ + ... + aₙxₙ {≤, ≥, ==} b`

| Function | Set | Form |
|----------|-----|------|
| `MOI.ScalarAffineFunction{Float64}` | `MOI.LessThan{Float64}` | `aᵀx ≤ b` |
| `MOI.ScalarAffineFunction{Float64}` | `MOI.GreaterThan{Float64}` | `aᵀx ≥ b` |
| `MOI.ScalarAffineFunction{Float64}` | `MOI.EqualTo{Float64}` | `aᵀx == b` |

#### Variable-on-Set Constraints
Special case where constraint is a single variable:

| Function | Set | Form |
|----------|-----|------|
| `MOI.VariableIndex` | `MOI.LessThan{Float64}` | `x ≤ b` |
| `MOI.VariableIndex` | `MOI.GreaterThan{Float64}` | `x ≥ b` |
| `MOI.VariableIndex` | `MOI.EqualTo{Float64}` | `x == b` |
| `MOI.VariableIndex` | `MOI.Interval{Float64}` | `lb ≤ x ≤ ub` |

### ✅ Quadratic Constraints

Constraints with quadratic terms: `x₁² + x₁x₂ + ... {≤, ≥, ==} b`

| Function | Set | Form |
|----------|-----|------|
| `MOI.ScalarQuadraticFunction{Float64}` | `MOI.LessThan{Float64}` | `½xᵀQx + aᵀx ≤ b` |
| `MOI.ScalarQuadraticFunction{Float64}` | `MOI.GreaterThan{Float64}` | `½xᵀQx + aᵀx ≥ b` |
| `MOI.ScalarQuadraticFunction{Float64}` | `MOI.EqualTo{Float64}` | `½xᵀQx + aᵀx == b` |

**Note**: Xpress supports both convex and non-convex quadratic constraints.

### ✅ Nonlinear Constraints

General nonlinear constraints using Xpress's native NLP solver:

| Function | Set | Form |
|----------|-----|------|
| `MOI.ScalarNonlinearFunction` | `MOI.LessThan{Float64}` | `f(x) ≤ b` |
| `MOI.ScalarNonlinearFunction` | `MOI.GreaterThan{Float64}` | `f(x) ≥ b` |
| `MOI.ScalarNonlinearFunction` | `MOI.EqualTo{Float64}` | `f(x) == b` |

**Supported Nonlinear Functions**:
- Standard operators: `+`, `-`, `*`, `/`, `^`
- Transcendental functions: `exp`, `log`, `log10`, `sqrt`
- Trigonometric: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`
- Hyperbolic: `sinh`, `cosh`, `tanh`
- Statistical (SpecialFunctions.jl): `erf` (error function), `erfc` (complementary error function)
- Other: `abs`, `sign`, `min`, `max`

**Custom User-Defined Operators**: Supports JuMP's `@operator` macro for user-defined functions with provided derivatives.

### ✅ Indicator (Implication) Constraints

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

### ✅ Special Ordered Sets (SOS)

| Function | Set | Description |
|----------|-----|-------------|
| `MOI.VectorOfVariables` | `MOI.SOS1{Float64}` | At most one variable in the set can be non-zero |
| `MOI.VectorOfVariables` | `MOI.SOS2{Float64}` | At most two consecutive variables can be non-zero |

---

## Objective Functions

### ✅ Supported Objective Types

| Objective Function Type | Description |
|------------------------|-------------|
| `MOI.VariableIndex` | Single variable objective: `min/max x` |
| `MOI.ScalarAffineFunction{Float64}` | Linear objective: `min/max aᵀx + b` |
| `MOI.ScalarQuadraticFunction{Float64}` | Quadratic objective: `min/max ½xᵀQx + aᵀx + b` |
| `MOI.ScalarNonlinearFunction` | Nonlinear objective: `min/max f(x)` (via slack bridge) |
| `MOI.VectorOfVariables` | Multi-objective: Native support for multiple objectives |

### ✅ Objective Sense

| Sense | MOI Constant | Description |
|-------|--------------|-------------|
| **Minimize** | `MOI.MIN_SENSE` | Minimize objective function |
| **Maximize** | `MOI.MAX_SENSE` | Maximize objective function |
| **Feasibility** | `MOI.FEASIBILITY_SENSE` | Find any feasible solution |

---

## Solver Attributes

### ✅ Standard MOI Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `MOI.Name` | `String` | Problem name |
| `MOI.Silent` | `Bool` | Suppress solver output |
| `MOI.TimeLimitSec` | `Float64` | Time limit in seconds |
| `MOI.NodeLimit` | `Int` | Maximum number of branch-and-bound nodes |
| `MOI.NumberOfThreads` | `Int` | Number of threads for parallel solving |
| `MOI.ObjectiveSense` | `MOI.OptimizationSense` | Min/Max/Feasibility |
| `MOI.ObjectiveValue` | `Float64` | Objective value of solution |
| `MOI.ObjectiveBound` | `Float64` | Best known bound on objective |
| `MOI.RelativeGap` | `Float64` | Relative MIP gap |
| `MOI.SolveTimeSec` | `Float64` | Time spent solving |
| `MOI.SimplexIterations` | `Int` | Simplex iterations |
| `MOI.BarrierIterations` | `Int` | Barrier iterations |
| `MOI.NodeCount` | `Int` | Nodes explored in branch-and-bound |
| `MOI.ResultCount` | `Int` | Number of solutions (always 1 for Xpress) |
| `MOI.RawStatusString` | `String` | Human-readable solver status |
| `MOI.SolverVersion` | `String` | Runtime Xpress library version as `major.minor.build` |
| `MOI.ObjectiveFunctionType` | `Type` | Type of the objective function currently set |
| `MOI.ListOfConstraintTypesPresent` | `Vector{Tuple{Type,Type}}` | Each `(F, S)` constraint-type tuple present, once |
| `MOI.DualObjectiveValue` | `Float64` | Dual-solution objective after an LP solve (matches `ObjectiveValue` at optimality) |

### ✅ Variable Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `MOI.VariableName` | `String` | Variable name |
| `MOI.VariablePrimal` | `Float64` | Primal solution value |
| `MOI.VariablePrimalStart` | `Float64` | Warm-start value (MIP start) |

### ✅ Constraint Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `MOI.ConstraintName` | `String` | Constraint name |
| `MOI.ConstraintPrimal` | `Float64` | Primal value of constraint |
| `MOI.ConstraintDual` | `Float64` | Dual value (for LP/QP), reported with the MOI sign convention (relative to minimization); variable-bound duals are the column reduced cost |
| `MOI.ConstraintFunction` | `Function` | Get constraint function |
| `MOI.ConstraintSet` | `Set` | Get or set the constraint set (in-place modification supported for bounds and affine RHS) |
| `MOI.ConstraintConflictStatus` | `MOI.ConflictStatusCode` | IIS membership |

### ✅ Raw Optimizer Attributes

Access any Xpress control or attribute directly:

```julia
MOI.set(model, MOI.RawOptimizerAttribute("PRESOLVE"), 0)  # Disable presolve
gap = MOI.get(model, MOI.RawOptimizerAttribute("MIPRELGAP"))  # Get MIP gap
```

**All Xpress controls and attributes** are accessible via `MOI.RawOptimizerAttribute`.

---

## Solution Status

### ✅ Termination Status Codes

XpressAPI maps Xpress solve status to MOI termination codes:

| MOI Termination Status | Xpress Status | Description |
|----------------------|---------------|-------------|
| `MOI.OPTIMIZE_NOT_CALLED` | `XPRS_SOLVESTATUS_UNSTARTED` | Solve not started |
| `MOI.OPTIMAL` | `XPRS_SOLSTATUS_OPTIMAL` | Optimal solution found |
| `MOI.LOCALLY_SOLVED` | `XPRS_SOLSTATUS_FEASIBLE` | Feasible solution found (MIP) |
| `MOI.INFEASIBLE` | `XPRS_SOLSTATUS_INFEASIBLE` | Problem is infeasible |
| `MOI.DUAL_INFEASIBLE` | `XPRS_SOLSTATUS_UNBOUNDED` | Problem is unbounded |
| `MOI.TIME_LIMIT` | `XPRS_STOP_TIMELIMIT` | Time limit reached |
| `MOI.NODE_LIMIT` | `XPRS_STOP_NODELIMIT` | Node limit reached |
| `MOI.ITERATION_LIMIT` | `XPRS_STOP_ITERLIMIT` | Iteration limit reached |
| `MOI.SOLUTION_LIMIT` | `XPRS_STOP_SOLLIMIT` | Solution limit reached |
| `MOI.MEMORY_LIMIT` | `XPRS_STOP_MEMORYERROR` | Memory limit reached |
| `MOI.NUMERICAL_ERROR` | `XPRS_STOP_NUMERICALERROR` | Numerical difficulties |
| `MOI.INTERRUPTED` | `XPRS_STOP_CTRLC` | User interrupt |
| `MOI.OTHER_LIMIT` | `XPRS_STOP_MIPGAP`, `XPRS_STOP_WORKLIMIT` | Other limits |
| `MOI.OTHER_ERROR` | Various | Other solver errors |

### ✅ Result Status Codes

| MOI Result Status | Description |
|------------------|-------------|
| `MOI.FEASIBLE_POINT` | Solution is feasible |
| `MOI.INFEASIBLE_POINT` | Solution is infeasible |
| `MOI.NO_SOLUTION` | No solution available |
| `MOI.INFEASIBILITY_CERTIFICATE` | Ray proving infeasibility |
| `MOI.NEARLY_FEASIBLE_POINT` | Solution within tolerances |

---

## Callbacks

XpressAPI supports MOI callbacks for customizing the branch-and-bound process:

### Supported Callbacks

| Callback Type | MOI Type | Description | When Called |
|--------------|----------|-------------|-------------|
| **User Cuts** | `MOI.UserCutCallback` | Add cutting planes | At fractional LP solutions |

### Not Yet Supported

| Callback Type | MOI Type | Status |
|--------------|----------|--------|
| **Lazy Constraints** | `MOI.LazyConstraintCallback` | Not implemented (`MOI.supports` returns `false`) |
| **Heuristic** | `MOI.HeuristicCallback` | Not implemented (`MOI.supports` returns `false`) |

### Callback Functions

Inside callbacks, you can:

#### ✅ Query Callback Data

```julia
function my_callback(cb_data::XPRSprob)
    # Get variable value at callback node
    x_val = MOI.get(model, MOI.CallbackVariablePrimal(cb_data), x)

    # Check if node solution is integer
    status = MOI.get(model, MOI.CallbackNodeStatus(cb_data))
    if status == MOI.CALLBACK_NODE_STATUS_INTEGER
        # All integer variables are at integer values
    elseif status == MOI.CALLBACK_NODE_STATUS_FRACTIONAL
        # Some integer variables are fractional
    end
end
```

#### Submit Cuts

```julia
# Submit a user cut (must not cut off integer feasible solutions)
MOI.submit(model, MOI.UserCut(cb_data), func, set)
```

Submitting lazy constraints (`MOI.LazyConstraint`) and heuristic solutions
(`MOI.HeuristicSolution`) is not yet supported.

**Supported Callback Constraint Types**:
- `MOI.ScalarAffineFunction` with `MOI.LessThan`, `MOI.GreaterThan`, or `MOI.EqualTo`

---

## Bridges

### ✅ Custom Objective Bridge

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

**Note**: Xpress natively supports variable, linear, quadratic, and multi-objective optimization without requiring bridges.

### ✅ MOI Bridge Support

XpressAPI works seamlessly with MOI's automatic bridging system, which can transform:
- Conic constraints → Quadratic constraints (e.g., `MOI.SecondOrderCone`)
- Interval constraints → Separate bounds
- Quadratic objectives → Linear objectives with constraints
- And many more transformations

JuMP adds these bridges automatically, so no special setup is required -- just
create the model with the optimizer directly:
```julia
using JuMP, XpressAPI
model = Model(XpressAPI.Optimizer)
```

---

## Incremental Interface

### ✅ Incremental Problem Building

XpressAPI supports **incremental problem construction**:

```julia
MOI.supports_incremental_interface(::XpressAPI.Optimizer) # Returns true
```

You can:
- ✅ Add variables one at a time
- ✅ Add constraints incrementally
- ✅ Modify objective function
- ✅ Change variable bounds and affine right-hand sides in place
- ✅ Solve multiple times with modifications

### Modification Operations

| Operation | Supported | Notes |
|-----------|-----------|-------|
| Add variables | ✅ | `MOI.add_variable` / `MOI.add_variables` |
| Add constraints | ✅ | `MOI.add_constraint` / `MOI.add_constraints` |
| Delete variables | ❌ | `MOI.delete` is not yet implemented |
| Delete constraints | ❌ | `MOI.delete` is not yet implemented |
| Modify constraint function | ✅ | `MOI.set(MOI.ConstraintFunction(), ...)` |
| Modify constraint set (bounds / RHS) | ✅ | `MOI.set(MOI.ConstraintSet(), ...)` -- see below |
| Modify objective | ✅ | `MOI.set(MOI.ObjectiveFunction(), ...)` |
| Modify objective sense | ✅ | `MOI.set(MOI.ObjectiveSense(), ...)` |
| Set starting values | ✅ | `MOI.set(MOI.VariablePrimalStart(), ...)` |

#### In-place `set(MOI.ConstraintSet)`

Variable bounds (`GreaterThan`, `LessThan`, `EqualTo`, `Interval`) and affine
constraint right-hand sides can be modified in place without rebuilding the
model. The change routes through `XPRSchgbounds` / `XPRSchgrhs`, so a subsequent
`optimize!` (a re-solve or warm-start loop) reflects the new set.

```julia
# Relax an upper bound in place, then re-solve.
MOI.set(model, MOI.ConstraintSet(), ci, MOI.LessThan(6.0))
optimize!(model)
```

`Interval` bounds are stored internally as separate lower/upper bound
constraints; setting either child bound refreshes the parent's cached
`Interval`. In-place modification of `Semicontinuous` / `Semiinteger` bounds is
**not** supported and throws `MOI.SetAttributeNotAllowed` -- delete and re-add
the constraint instead.

---

## Conflict Analysis (IIS)

### ✅ Irreducible Inconsistent Subsystem (IIS)

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

## Warm Starting

### ✅ MIP Start Values

Provide initial solutions to guide the MIP solver:

```julia
using JuMP, XpressAPI

model = Model(XpressAPI.Optimizer)
@variable(model, x, Int)
@variable(model, y, Int)

# Provide warm start values
set_start_value(x, 5.0)
set_start_value(y, 3.0)

optimize!(model)
```

**Note**: Warm starts are hints to the solver and may be ignored if infeasible.

---

## Copy/Clone Support

### ✅ Model Copying

XpressAPI supports copying models via the default MOI copy mechanism:

```julia
dest = XpressAPI.Optimizer()
MOI.copy_to(dest, src)  # Copy src model to dest
```

This enables:
- Creating backups of models
- Solving modified copies
- Multi-start optimization

---

## Not Currently Supported

### ❌ Features Not Implemented

The following MOI features are **not yet supported** in XpressAPI:

#### Conic Constraints (Direct)
- ❌ `MOI.SecondOrderCone` (can be bridged to quadratic)
- ❌ `MOI.RotatedSecondOrderCone` (can be bridged to quadratic)
- ❌ `MOI.ExponentialCone`
- ❌ `MOI.DualExponentialCone`
- ❌ `MOI.PowerCone`
- ❌ `MOI.DualPowerCone`
- ❌ `MOI.GeometricMeanCone`
- ❌ `MOI.NormCone`
- ❌ `MOI.PositiveSemidefiniteConeTriangle`

**Workaround**: Use MOI bridges to reformulate conic constraints as quadratic constraints.

#### Advanced Features
- ❌ `MOI.LazyConstraintCallback` / `MOI.LazyConstraint` (not implemented)
- ❌ `MOI.HeuristicCallback` / `MOI.HeuristicSolution` (not implemented)
- ❌ Multiple solutions / Solution pool access (Xpress has solution pools but not exposed via MOI)
- ❌ Sensitivity analysis via MOI (use Xpress API directly)
- ❌ Parameter tuning hints

#### Modifications
- ❌ `MOI.delete` for variables and constraints (not yet implemented)
- ❌ `MOI.modify` (e.g. `MOI.ScalarCoefficientChange`) (not yet implemented)
- ❌ Modifying variable domains after creation (e.g., continuous -> integer)
- ❌ Column generation within MOI (use Xpress API directly)
- ❌ Constraint modification for nonlinear constraints (limited support)

---

## Usage Example

Here's a complete example using XpressAPI with JuMP:

```julia
using JuMP, XpressAPI

# Create model with XpressAPI optimizer
model = Model(XpressAPI.Optimizer)

# Suppress output
set_silent(model)

# Set time limit
set_time_limit_sec(model, 300.0)

# Variables
@variable(model, x >= 0)
@variable(model, y >= 0)
@variable(model, z, Bin)  # Binary variable

# Linear constraints
@constraint(model, c1, 2x + 3y <= 10)
@constraint(model, c2, x - y >= -5)

# Quadratic constraint
@constraint(model, qc, x^2 + y^2 <= 25)

# Indicator constraint
@constraint(model, indicator, z => {x + y >= 3})

# Quadratic objective
@objective(model, Min, x^2 + 2y^2 + x + y)

# Solve
optimize!(model)

# Get solution
if termination_status(model) == OPTIMAL
    println("Optimal solution found!")
    println("x = ", value(x))
    println("y = ", value(y))
    println("z = ", value(z))
    println("Objective = ", objective_value(model))

    # Get constraint duals (for LP/QP)
    if !is_binary(z)
        println("Dual of c1 = ", dual(c1))
    end
end

# Access Xpress-specific attributes
nodes = MOI.get(model, MOI.NodeCount())
gap = MOI.get(model, MOI.RelativeGap())

# Access raw Xpress controls
prob = backend(model)
MOI.set(prob, MOI.RawOptimizerAttribute("PRESOLVE"), 2)
```

---

## Integration with JuMP

XpressAPI seamlessly integrates with JuMP's high-level modeling syntax:

```julia
using JuMP
import XpressAPI

# Option 1: Direct usage (JuMP adds the required bridges automatically)
model = Model(XpressAPI.Optimizer)

# Option 2: Deferred optimizer attachment
model = Model()
# ... build model ...
set_optimizer(model, XpressAPI.Optimizer)
```

All JuMP macros work naturally:
- `@variable`, `@constraint`, `@objective`
- `@expression`, `@NLconstraint`, `@NLobjective`
- `@operator` for custom nonlinear functions
- Vectorized constraints and constraints on collections

---

## Performance Considerations

### Efficient Problem Building

- **Batch operations**: Use `MOI.add_constraints` instead of multiple `MOI.add_constraint` calls
- **Preallocate**: Set variable counts upfront when possible
- **Sparse arrays**: Xpress handles sparse constraint matrices efficiently
- **Warm starts**: Provide good initial solutions for MIP problems

### Problem Types

| Problem Type | Performance | Notes |
|-------------|-------------|-------|
| LP | ★★★★★ | Excellent, use dual simplex by default |
| QP (convex) | ★★★★★ | Excellent, native support |
| QP (non-convex) | ★★★★☆ | Good, global solver available |
| MILP | ★★★★★ | Excellent, world-class MIP solver |
| MIQP | ★★★★☆ | Good, especially for convex MIQP |
| NLP | ★★★★☆ | Good, native NLP solver (SLP/SQP) |
| MINLP | ★★★☆☆ | Moderate, use spatial branch-and-bound |

---

## Summary

XpressAPI provides a **comprehensive and production-ready** MOI interface with:

✅ **Full coverage** of linear, quadratic, and nonlinear optimization
✅ **Rich constraint types** including indicators and SOS
✅ **User cut callback support** for custom branch-and-bound logic
✅ **Incremental interface** for dynamic problem modification
✅ **Conflict analysis** for debugging infeasible models
✅ **Warm starting** for faster MIP solves
✅ **Well-organized, modular** Julia code

The implementation follows MOI best practices and integrates seamlessly with JuMP for high-level mathematical optimization modeling.

---

## Further Information

- **Xpress Optimizer Documentation**: [https://www.fico.com/en/products/fico-xpress-optimization](https://www.fico.com/en/products/fico-xpress-optimization)
- **MathOptInterface Documentation**: [https://jump.dev/MathOptInterface.jl/stable/](https://jump.dev/MathOptInterface.jl/stable/)
- **JuMP Documentation**: [https://jump.dev/JuMP.jl/stable/](https://jump.dev/JuMP.jl/stable/)
- **XpressAPI Source**: Check `XpressAPI/ext/` directory for implementation details

For questions or issues, please report to the FICO Xpress support team or consult the Xpress user community.