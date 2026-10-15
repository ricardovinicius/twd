---
name: project-standards-review
description: "Review code and project organization against repository instructions, feature specs, and established architectural standards. Use for project standards audits, code reviews, and requests to apply their findings. Includes Godot scene and resource checks when relevant."
---

# Project Standards Review

Review the implementation against the project's own contract, substantiate findings with real consumers and runtime behavior, and apply focused corrections when authorized.

## Establish the contract and scope

- Read applicable `AGENTS.md` files, relevant feature specs, and architecture/testing documentation. Use the user's current decisions over conflicting older documentation. Distinguish explicit requirements, inferred conventions, and optional recommendations; do not silently turn an inference into a rule.
- Inspect the working tree and relevant diffs before editing. Review the requested changes or feature by default; audit the whole project when requested. Preserve unrelated work and do not commit unless asked.
- For a review/check request, report findings without changing production code. For a fix/apply request, or when prior authorization already covers corrections, implement and verify the findings without asking again. A review does not itself authorize a repository-wide reorganization.
- If a spec and implementation disagree, establish which behavior the user intends before changing gameplay. A historical MVP limitation may have been superseded by a later feature.

## Check ownership and boundaries

Follow the architecture actually chosen by the project. In a feature-driven project:

- Keep feature-owned scenes, scripts, data contracts, resources, UI, and dedicated assets together. Feature-specific presentation may remain inside that feature, such as `spells/ui/`; do not centralize all UI just because it is UI.
- Trace actual production consumers before proposing extraction or relocation. Several scenes within one feature, hypothetical future reuse, and test fixtures do not establish reuse across features.
- Keep shared components and assets where multiple features actually use them. A root `assets/` directory is appropriate for shared artwork, not a miscellaneous destination. An existing domain folder such as `health/` can already be a valid feature boundary.
- Identify ambiguous buckets, scattered implementations, duplicate entry points, and misplaced definition/scene files. Give concrete source and destination paths for justified moves, without imposing a new universal directory tree.

Inspect behavior as well as file placement:

- Focused composed components, small public APIs, and explicit dependencies instead of arbitrary external scene-tree searches.
- A single authoritative owner for each state, separate shared configuration and per-instance runtime state, and presentation derived from gameplay state.
- Effects dispatched through the project's data/receiver/reaction contracts rather than direct mutation of concrete targets.
- Signals emitted after state changes, idempotent no-ops, rejected operations preserving state, and cleanup of commands, timers, references, and temporary collision changes.
- Configuration and invalid-input handling that fails safely, plus naming and spec/test conventions defined by the repository.

These are review dimensions, not permission to add abstractions or rewrite working systems. Prioritize demonstrated bugs and explicit contract violations.

## Substantiate findings

- Trace each issue to callers, composed scenes, resource configuration, or a reproducible failure. Separate confirmed findings from suspected risks.
- Lead findings with severity, a concrete trigger and consequence, and a file/line reference. Explain the violated local rule and the smallest useful correction. Treat naming and placement issues proportionally to their actual impact.
- Exercise the real integration path when simplified fixtures can hide configuration. For example, checking a projectile under an unscaled dummy does not establish its behavior under the configured player scene.
- For Godot, inspect autoload paths, scene dependencies, exported references, and signal argument order, including arguments appended by `Callable.bind()`. When changing effect parents, check inherited position, rotation, scale, collision size, and lifetime ownership. Verify world-space behavior explicitly where required.
- Do not claim exhaustive coverage from a sample or count failures caused by one broken fixture as independently proven gameplay defects.

## Apply and verify authorized fixes

- Keep behavioral fixes and organizational moves identifiable in the diff. Move related files together, preserve UID/import sidecars, and update code, scene/resource paths, tests, and affected documentation. Keep existing behavior unless the requested correction requires a change.
- Consolidate duplicate implementations only after checking references and intended behavior. Do not delete ambiguous user artifacts as incidental cleanup.
- Add regression coverage for demonstrated behavioral failures and meaningful integration boundaries. Avoid tests that merely mirror implementation details or verify reversible naming edits.
- Use the project's existing runners and prepare required imports/build artifacts before interpreting failures. Check whether a runner actually fails on script errors, aborted checks, and missing completion, rather than trusting exit status or a printed PASS alone. Do not hide new errors with blanket log filtering.
- Run the suites affected by the change, resource/reference checks for moves, and relevant application smoke checks. Once those pass, repeat or broaden checks only for new changes or unresolved concerns. State which visual or manual behavior was not verified.

## Report the result

For reviews, lead with actionable findings ordered by severity, followed by coverage and verification limits. Say when no substantiated issues were found. For fixes, explain the resulting behavior, the important moves or boundary changes, the validation performed, and any remaining issue. Distinguish file moves/reference updates from gameplay changes so a large diff is understandable.
