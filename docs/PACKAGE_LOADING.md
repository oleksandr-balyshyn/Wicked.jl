# Package loading and precompilation

This guide captures the operational workflow for reliable Wicked.jl startup in development, CI, and shipping applications.

## Why this matters

`Wicked.API` is imported like any regular Julia package module, but startup behavior is heavily affected by project activation, dependencies, and cache state. Use deterministic commands whenever startup time, reproducibility, or first-run failures matter.

## Canonical load flow

1. Activate the intended environment (`--project` or active default).
2. Resolve dependencies for that environment.
3. (Optional but recommended in CI) precompile caches.
4. Import `Wicked.API` as the production-facing entrypoint.

```julia
using Pkg

Pkg.activate(".")
Pkg.instantiate()
Pkg.precompile()      # recommended for CI/build reproducibility
using Wicked.API
```

## Useful shell pattern

```sh
julia --project=. --startup-file=no \
  -e 'using Pkg; Pkg.activate("."); Pkg.instantiate(); Pkg.precompile(); using Wicked.API'
```

Use this in CI or release pipelines when startup latency and deterministic output are required.

## What precompile changes (and what it does not)

- It precompiles package code and dependencies for the active Julia version + manifest.
- It does not execute your app state machine, `run(...)`, or domain logic.
- Cache reuse only happens when source/manifest/Julia environment are unchanged.
- On cache misses, Julia recompiles affected modules automatically and replaces stale artifacts.

## Operational troubleshooting

1. Confirm active environment and manifest:

```julia
import Pkg
Pkg.status()
Base.active_project()
```

2. Force a clean activation and load in one shot:

```julia
using Pkg
Pkg.activate(".")
Pkg.resolve()
Pkg.instantiate()
Pkg.precompile()
using Wicked.API
```

3. Verify load result:

```julia
isdefined(Wicked, :API)    # true
```

4. If the issue appears cache-related and reproducible:

```sh
rm -rf ~/.julia/compiled
rm -rf ~/.julia/logs
```

Then rerun the bootstrap command above.

## CI/reproducibility profile

- Set threads explicitly to 1 for predictable timings in tests:

```sh
JULIA_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=1 julia --project=. --startup-file=no -e 'using Pkg; Pkg.instantiate(); using Wicked.API'
```

- For release builds, call precompile during packaging and capture `Pkg.status()` output in logs.

## Notes for package developers

- In local editable mode (`Pkg.develop`) keep one local checkout active and restart Julia after source/manifests changes if load errors persist.
- Prefer `using Wicked.API` in application entry code to keep the exported surface stable and stable.
