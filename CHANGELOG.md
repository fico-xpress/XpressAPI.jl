# XpressAPI release notes

All notable changes to the XpressAPI Julia package are documented here.
Version numbers track the FICO Xpress version from which the bindings were
generated.

## 47.1.5

- Fixed newly added JuMP / MOI variables silently defaulting to a lower bound of
  `0.0`. MOI variables are free by default (`-Inf`, `+Inf`), but Xpress defaults
  a column's lower bound to `0.0`, so a variable with no explicit bound was made
  non-negative -- causing wrong results or spurious infeasibilities for models
  relying on free variables. New variables are now created with an explicit
  `-Inf` lower bound.
- Added in-place `set(::Optimizer, ::MOI.ConstraintSet, ...)` to the JuMP / MOI
  interface. Variable bounds (`GreaterThan`, `LessThan`, `EqualTo`, `Interval`)
  and affine constraint right-hand sides can now be modified without rebuilding
  the model, routing through `XPRSchgbounds` / `XPRSchgrhs`, so warm-start and
  re-solve loops pick up the new set on the next `optimize!`.
- Added `MOI.DualObjectiveValue` to the JuMP / MOI interface. It reports the
  objective value of the dual solution after an LP solve, derived from the
  constraint duals so that it follows the MOI sign convention and, at
  optimality, matches `MOI.ObjectiveValue` within tolerance.
- Fixed the `MOI.ConstraintDual` sign conventions in the JuMP / MOI interface.
  Duals are now reported relative to a minimization problem as MOI requires
  (negated for maximization models), so a `GreaterThan` row/bound has a
  non-negative dual and a `LessThan` one a non-positive dual regardless of the
  objective sense. Duals of variable bounds are now returned as the column
  reduced cost (via `XPRSgetredcosts`) instead of `NaN`, and the dual of a
  parent constraint (such as a split `Interval` bound) is taken from its
  binding child; the vector getter now returns a flat `Vector` rather than a
  malformed nested one.
- Shipped `MOI_FEATURES.md` inside the installed package. The README links to
  it, but it was previously omitted from the install, leaving a dead link. The
  bridge-usage examples in that document were also corrected to create the
  model directly with `Model(XpressAPI.Optimizer)` (JuMP adds the required
  bridges automatically) rather than wrapping it in a
  `MOI.Bridges.full_bridge_optimizer`, and the README wording no longer claims
  the package provides no modeling API given the JuMP / MOI extension it ships.
- Continued the low-level wrapper clean-up following upstream review feedback:
  string arguments and results now use the concrete `String` type (and name
  lists are returned as `Vector{String}`) instead of `AbstractString`, except
  for name-array inputs which stay generic so any string vector can be passed;
  wrapped functions emit an explicit `return`; and the docstring signature line
  now shows the return type rather than the output parameter names.
- Fixed the "argument too short" error raised when a pre-allocated output
  array is smaller than required. The generated code concatenated the required
  length (an integer) directly onto the message string, which threw an opaque
  `MethodError` instead of the intended `XPRSexception`; the length is now
  converted with `string(...)`.
- Fixed an intermittent heap-corruption crash on Windows (an access violation
  during garbage collection) that could occur while a callback was active
  during a solve. Each callback invocation previously allocated a fresh
  problem wrapper to pass to the user callback; because callbacks run
  re-entrantly while the solver holds the call stack, this per-invocation
  allocation could trigger garbage collection at an unsafe point. The wrapper
  is now created once and reused across all invocations of a given callback,
  so callbacks no longer allocate it per call. Note: this reuse is only safe
  because MIP branch-and-bound callbacks are serialised on the main thread
  (`XPRS_CALLBACKFROMMAINTHREAD`). That guarantee does not hold for the
  SLP / nonlinear / multistart solves, where the optimizer may invoke
  callbacks from worker threads; callbacks are not currently safe to use
  during those solves.

## 47.1.4

- Added `MOI.SolverVersion` to the JuMP / MOI interface. It reports the version
  of the Xpress library actually loaded at runtime (via
  `XPRSgetversionnumbers`), which may differ from the version the bindings were
  built against, as a `major.minor.build` string.
- Added `MOI.ListOfConstraintTypesPresent` to the JuMP / MOI interface. It
  reports each `(F, S)` constraint-type tuple currently present in the model
  exactly once.
- Added `MOI.ObjectiveFunctionType` to the JuMP / MOI interface. It reports the
  type of the objective function currently set (`MOI.VariableIndex`,
  `MOI.ScalarAffineFunction`, `MOI.ScalarQuadraticFunction`, or
  `MOI.VectorOfVariables`), defaulting to `MOI.ScalarAffineFunction` when no
  objective has been set.
- Fixed the low-level wrapper for deferred-reference (dref) output-array
  functions such as `XPRSgetqrowqmatrixtriplets` when called with
  pre-allocated arrays (or `nothing`). The generated code previously skipped
  the C call on that path, returning the untouched input arrays and a size of
  0; it now issues the call and returns the correct data and size.
- Hardened the generated bindings against a garbage-collection use-after-free
  that could corrupt the heap (observed as intermittent access violations on
  Windows). String output buffers are now kept alive with `GC.@preserve`
  across the `unsafe_string(pointer(...))` conversion, and callbacks are rooted
  in the problem's callback list before being registered with the C library.
- Reported callback support accurately: `MOI.supports` now returns `true` only
  for `MOI.UserCutCallback` (the one implemented callback) and `false` for
  `MOI.LazyConstraintCallback` and `MOI.HeuristicCallback`, instead of a
  blanket `true` that made JuMP offer callbacks that then failed at runtime.
  The feature docs were corrected to match.
- Cleaned up the generated low-level wrapper following upstream review
  feedback: module globals are now `const` or concretely typed (avoiding the
  untyped-global performance penalty); `Libdl`/`SparseArrays` are brought in
  with `import` and referenced qualified; the broken default argument on
  `Base.showerror` was removed; and redundant `global`/`export` statements
  were dropped (all `XPRS`-prefixed symbols are exported by a single loop).
- Fixed the `SparseMatrixCSC` overload of `XPRSaddcols`, which passed a
  malformed `map.nzval` instead of the matrix's non-zero values.

## 47.1.3

- Added warm-start support to the JuMP / MOI interface via `set_start_value`
  (`MOI.VariablePrimalStart`). The starting point is forwarded to the solver
  according to the problem type: MIP starts through `XPRSaddmipsol`, non-linear
  starts through `XPRSnlpsetinitval` (both accept partial solutions), and pure
  LP starts through `XPRSloadlpsol` (which requires a complete vector, so
  unset variables are filled from their bounds or zero). Basis reuse across
  solves is left to the user to drive explicitly with `XPRSgetbasis` /
  `XPRSloadbasis`; the interface does not cache and reload a basis implicitly.

## 47.1.2

- Fixed `compute_conflict!` so that an infeasible subproblem is reported as
  `MOI.CONFLICT_FOUND` even when the IIS search did not finish (for example,
  when it was stopped by a time limit) or when the returned infeasible set is
  not guaranteed to be irreducible. Previously such results were silently
  dropped and reported as no conflict.
- Constrained the `julia` compat entry to a bounded range so the package
  satisfies the Julia General registry AutoMerge requirements.

## 47.1.1

- Introduced the JuMP / MathOptInterface (MOI) interface, shipped as the
  `XpressMOIExt` package extension. This provides an `Optimizer` usable from
  JuMP, including linear, quadratic, nonlinear, SOS and indicator constraints,
  callbacks, and IIS/conflict support.
- Added DREF-style array allocation helpers for the low-level wrapper.
- Fixed Windows-specific callback and test issues.

## 44.1.1

- First public release. Introduced the low-level Julia wrapper for the Xpress
  Optimizer C API: a Julia function wrapper for every supported C function,
  with error-code translation, output parameters returned as values, optional
  array allocation, resource finalizers, and callback support.
