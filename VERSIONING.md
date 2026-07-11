# Versioning and Deprecation Policy

Wicked.jl follows [Semantic Versioning 2.0](https://semver.org/) for stable releases.

## Before 1.0

While the package version is `0.y.z`:

- A minor release may change public APIs when the change is documented in `CHANGELOG.md` and migration guidance is provided.
- A patch release fixes behavior without intentionally breaking documented public APIs.
- Experimental APIs are identified in documentation and may change faster than the stable core.
- No `0.x` release is described as production-ready until the release checklist has complete evidence.

Pre-1.0 flexibility is not permission for silent breakage. Prefer additive changes and deprecations when a practical transition path exists.

## From 1.0 onward

- A major release may contain breaking public API or behavioral changes.
- A minor release adds backward-compatible functionality and may add deprecations.
- A patch release contains backward-compatible fixes, security patches, and documentation corrections.

## Public compatibility surface

The compatibility contract includes:

- Exported types, constructors, functions, keywords, and documented multiple-dispatch extension points.
- Documented widget state transitions and managed runtime message/command behavior.
- Terminal lifecycle guarantees, capability fallback, and security bounds.
- Documented snapshot, semantic-tree, stylesheet, and trace formats.

Internal fields, underscored functions, undocumented submodule details, benchmark implementation, and test fixtures are not public API. Public struct fields that documentation tells applications to read or mutate are part of the contract even when an accessor also exists.

## Deprecation window

After `1.0`, a public API is deprecated for at least one minor release and at least 90 days before removal, whichever is longer. A deprecation must include:

- A runtime warning where practical.
- The replacement API and a migration example.
- A changelog entry naming the earliest removal release.

Immediate removal is reserved for actively exploitable security issues, legal requirements, or behavior that cannot be retained safely. Such removals require a security or release advisory and the narrowest feasible migration path.

## Julia compatibility

The minimum Julia version is declared in `Project.toml`. Raising it is a breaking change before `1.0` and a major-version change after `1.0`, unless the old Julia release is outside Julia's supported release lines and continuing support would prevent a necessary security fix. CI tests the declared minimum and the latest Julia `1.x` release.

## Extension compatibility

External widgets should extend documented open functions such as `render!`, `widget_semantic_descriptor`, and `widget_semantic_children`. Extensions must not depend on underscored functions or internal struct layout. New optional methods may be added in minor releases; existing documented method contracts follow the same deprecation policy as exported functions.
