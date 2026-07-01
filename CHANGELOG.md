# XpressAPI release notes

All notable changes to the XpressAPI Julia package are documented here.
Version numbers track the FICO Xpress version from which the bindings were
generated.

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
