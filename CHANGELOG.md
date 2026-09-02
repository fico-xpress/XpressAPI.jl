# XpressAPI release notes

All notable changes to the XpressAPI Julia package are documented here.
Version numbers track the FICO Xpress version from which the bindings were
generated.

## 47.1.6

- Implemented the remaining MathOptInterface callback family in the JuMP / MOI
  interface, completing the set that previously shipped only `UserCutCallback`:
  - `MOI.LazyConstraintCallback` with `MOI.submit(MOI.LazyConstraint(...), ...)`:
    lazy constraints may cut off an otherwise integer-feasible candidate. The
    callback runs in the `preintsol` hook. Cuts are stated by the user in the
    original space and translated into the presolved space with
    `XPRSpresolverow` before being added; a presolve failure is a hard error,
    since a lazy constraint that cannot be added would make the result
    incorrect. When the candidate is the node relaxation (`soltype == 0`) the
    cut is added directly with `XPRSaddcuts`, which implicitly rejects the
    candidate and propagates the cut to child nodes. For heuristic/user
    candidates (`soltype != 0`), where no node problem exists to attach a cut
    to, the cut is stored (`XPRSstorecuts`) and flushed into the tree from the
    `optnode` hook (`XPRSloadcuts`). Per-thread state (keyed by `MIPTHREADID`)
    keeps locally-valid cuts from being shared between MIP threads. Registering
    the callback disables dual reductions (`MIPDUALREDUCTIONS = 0`), since the
    model is assumed incomplete while lazy constraints are being added.
  - `MOI.UserCutCallback` now injects cuts from the `cutround` callback (the
    dedicated separation hook) and presolves each cut with `XPRSpresolverow`
    before adding it; an un-presolvable user cut is dropped (a user cut does not
    change the feasible region, so skipping it cannot make the result wrong).
  - `MOI.HeuristicCallback` with `MOI.submit(MOI.HeuristicSolution(...), ...)`:
    candidate MIP solutions are handed to Xpress via `XPRSaddmipsol`.
  - `Xpress.CallbackFunction`, a raw solver-specific hook that registers on the
    node-LP-solved callback and passes the underlying `XPRSprob` directly, for
    advanced use while still allowing the MOI in-callback getters
    (`CallbackVariablePrimal`, `CallbackNodeStatus`).
  `MOI.supports` now reports `true` for all three (it previously reported
  `false` for Lazy/Heuristic), and `MOI_FEATURES.md` / `README.md` no longer
  document them as unimplemented.
- Fixed `MOI.get(::CallbackVariablePrimal)` to read the in-callback solution
  with `XPRSgetcallbacksolution` instead of `XPRSgetsolution`. Inside a callback
  `XPRSgetsolution` does not return the current node/candidate solution, so the
  previous getter fed callbacks incorrect values; user cuts written against the
  fractional relaxation now see the actual relaxation point.
- Fixed `MOI.delete` of a variable bound (`GreaterThan` / `LessThan` /
  `EqualTo`) on a still-binary (`ZeroOne`) variable in the JuMP / MOI interface.
  Deleting the bound freed the column to `+/-Inf`, which pushed it outside
  `[0, 1]` and made Xpress silently reclassify the binary column `'B'` as a
  general integer `'I'`, so a subsequent solve could report the variable as
  unbounded (`DUAL_INFEASIBLE`) instead of respecting the surviving `ZeroOne`.
  The delete now detects a surviving `ZeroOne` and recomputes the column's
  bounds intersected with `[0, 1]`, keeping the column binary.
- Extended in-place `set(MOI.ConstraintSet)` to `Semicontinuous` and
  `Semiinteger` variable-bound constraints in the JuMP / MOI interface, which
  previously threw `MOI.SetAttributeNotAllowed`. Both pieces of the set's
  state are re-applied without rebuilding the model (the upper bound via
  `XPRSchgbounds` and the semi-continuous activation threshold via
  `XPRSchgglblimit`), mirroring the add path, so a re-solve or warm-start loop
  picks up the new `{0} u [lower, upper]` domain on the next `optimize!`. This
  completes the in-place variable-bound modification surface for every
  bound-like set type the interface accepts.
- Wired MathOptInterface's own upstream conformance suite
  (`MOI.Test.runtests`) into the JuMP / MOI test run. The suite exercises the
  Optimizer through the standard cache + full-bridge layer that JuMP uses,
  against the MOI specification rather than the hand-written example tests, and
  is the standing safety net for the MOI feature-parity effort. Genuinely
  unsupported features skip automatically; the remaining known gaps are listed
  in an explicit, grouped-by-root-cause exclusion list, each group annotated
  with the reason and its tracking story. Wiring up the suite immediately
  surfaced (and this release fixes) several correctness bugs:
  - Setting `MOI.ObjectiveSense` to `FEASIBILITY_SENSE` now clears the
    objective (a subsequent `ObjectiveValue` reads `0`) instead of leaving the
    previous objective in place.
  - Re-setting `MOI.ObjectiveFunction` now replaces the objective instead of
    accumulating: a second `set` no longer left the model looking like a
    multi-objective (with `ObjectiveValue` returning a vector).
  - Objectives with duplicate terms on the same variable are now summed before
    being handed to Xpress; previously `XPRSchgobjn` overwrote (last-wins),
    giving the wrong coefficient.
  - `MOI.get(ConstraintPrimal, ...)` for a variable-bound constraint now
    returns the variable's primal value (a scalar) instead of leaking a
    one-element vector / `NaN`.
  - `MOI.empty!` no longer errors when a nonlinear model is present
    (`MOI.Nonlinear.Model` implements `MOI.empty!`, not `Base.empty!`).
- Added `MOI.modify` with `MOI.ScalarQuadraticCoefficientChange` for quadratic
  constraints (`ScalarQuadraticFunction`-in-`{GreaterThan,LessThan,EqualTo}`) in
  the JuMP / MOI interface, in both the single-change and batched-vector forms. A
  quadratic constraint's Q coefficient can now be changed in place without
  rebuilding the row, routing through `XPRSchgqrowcoeff` so a re-solve picks up
  the new coefficient on the next `optimize!`. Unlike the quadratic *objective*
  modify, the coefficient is halved before storing (the quadratic-constraint add
  path stores `0.5*coef` in the Q matrix under the `½ xᵀQx` convention); the
  cached constraint function keeps the undoubled MOI coefficient. Column indices
  are canonicalized to the upper triangle, so argument order does not matter.
- Added `MOI.modify` with `MOI.MultirowChange` to the JuMP / MOI interface,
  changing one variable's coefficient across several rows of a single
  `VectorAffineFunction`-in-set constraint in one batched `XPRSchgmcoef` call so
  a re-solve reflects the new coefficients on the next `optimize!`. This also
  adds native support for `VectorAffineFunction` constraints in
  `MOI.Nonnegatives`, `MOI.Nonpositives`, and `MOI.Zeros` (previously reached
  only by MOI's scalarizing bridge): such a constraint is added as one
  constraint whose rows map directly to Xpress rows, so JuMP hands them to
  XpressAPI directly. Each `(output_row, new_coef)` pair uses a 1-based
  `output_row`; setting a coefficient to `0.0` removes the term from that row.
- Added in-place `MOI.modify` for quadratic objective coefficients
  (`MOI.ScalarQuadraticCoefficientChange`) in the JuMP / MOI interface, in both
  the single-change and batched-vector forms. A quadratic-programming objective
  coefficient can now be changed without rebuilding the objective, routing
  through `XPRSchgqobj` / `XPRSchgmqobj` so warm-start and re-solve loops pick
  up the new coefficient on the next `optimize!`. The coefficient is applied
  directly (no `0.5` factor): both MOI's `ScalarQuadraticFunction` and the
  Xpress objective use the `½ xᵀQx` convention. Modifying a `VectorOfVariables`
  (multi-)objective in place is rejected with `MOI.ModifyObjectiveNotAllowed`.
- Added `MOI.modify` with `MOI.ScalarCoefficientChange` to the JuMP / MOI
  interface. Linear coefficients of the objective and of affine constraints can
  now be changed in place for a single coefficient or a batch without
  rebuilding the model, routing through `XPRSchgobjn` (objective) and
  `XPRSchgcoef` / `XPRSchgmcoef` (constraints), so a re-solve reflects the new
  coefficients on the next `optimize!`. Setting a coefficient to `0.0` removes
  the term.
- Added `MOI.modify` with `MOI.ScalarConstantChange` for the objective to the
  JuMP / MOI interface. The objective's constant term can now be changed in
  place (routing through `XPRSsetobjdblcontrol` on `XPRS_OBJECTIVE_RHS`) without
  re-setting the whole objective, so the shifted constant is reflected in the
  reported objective value on the next `optimize!`. In-place objective
  modification now throws `MOI.ModifyObjectiveNotAllowed` when a
  `VectorOfVariables` multi-objective is active (where the single-objective
  assumption does not hold) instead of silently writing to the wrong objective.
- Cached the solution read-back in the JuMP / MOI interface. `MOI.VariablePrimal`,
  `MOI.ConstraintPrimal`, `MOI.ConstraintDual`, variable reduced costs, and the
  Farkas dual ray were previously read one element at a time, issuing a separate
  C call per variable or row. That was an O(n) cost paid on every getter, which
  is how JuMP reads a solution back element by element. Each is now fetched once
  in bulk after the solve and served from a per-solve cache (for example, reading
  every variable of a 40x40 assignment MIP dropped from tens of milliseconds to
  tens of microseconds). The caches are sized by `ORIGINALCOLS` / `ORIGINALROWS`
  so they stay correct when the solve leaves the problem in a presolved state,
  and are dropped as the first statement of every mutator (`optimize!`, `empty!`,
  any `MOI.modify` / `MOI.delete` / `set(MOI.ConstraintSet)` /
  `set(ObjectiveSense)`, variable addition, and constraint registration), ahead
  of any input validation or early return, so a no-op change or a call that
  throws after a partial mutation can never leave a stale solution cached.
- Fixed the length-mismatch guard in the batched constraint `MOI.modify`: it
  raised `MOI.NotAllowedError`, which is an abstract type that cannot be
  constructed, so a genuine `|cis| != |changes|` mismatch threw an opaque
  `MethodError` instead of a clear error. It now throws `DimensionMismatch`.

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
