# XpressAPI release notes

All notable changes to the XpressAPI Julia package are documented here.
Version numbers track the FICO Xpress version from which the bindings were
generated.

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
