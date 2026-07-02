# XpressAPI release notes

All notable changes to the XpressAPI Julia package are documented here.
Version numbers track the FICO Xpress version from which the bindings were
generated.

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
