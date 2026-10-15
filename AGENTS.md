# Overview

- This project is a game built with the Godot engine.
- Read the relevant feature specs in `docs/specs/` before implementing or changing gameplay behavior.

# Project organization

- Use a feature-driven directory structure. Place files according to the gameplay feature or system that owns them.
- Keep a feature's scenes, scripts, resources, data objects, UI, and dedicated assets together. For example, `spells/attack/magic_arrow/` owns the Magic Arrow command, projectile, definition, scenes, and sprites; spell-specific UI may live under `spells/ui/`.
- Keep feature-specific components inside their owning feature. Move components into a shared directory such as `components/` only when they are reused across features.
- Shared directories should have a clear purpose and actual consumers. Avoid vague collections such as `common`, `utils`, or `managers` without a defined responsibility.
- Keep assets used by one feature beside that feature. Use a shared asset directory for assets used across features.
- Organize tests and specs by feature under the existing `tests/` and `docs/specs/` directories.
- Keep dependencies between features explicit through public APIs, signals, exported references, and data contracts. Directory placement does not grant access to another feature's internal state.
- Extend the existing feature structure when adding functionality. Reorganize files when ownership or concrete reuse warrants it, updating all resource references when moving files.

# Patterns

- Composition-over-inheritance: Use composition over inheritance to create flexible and reusable components. Instead of creating a deep inheritance hierarchy, favor composing objects with smaller, focused components that can be combined to achieve the desired behavior.
- Keep components focused, with explicit contracts and clearly owned state. Entity scripts coordinate composed movement, detection, combat, health, and presentation components.
- Start with concrete implementations and small APIs. Extract shared abstractions when concrete reuse demonstrates a need; keep inheritance shallow where a shared contract is useful.

# Responsibilities and spell lifecycle

- Separate input recognition, spell configuration, invocation, and spell behavior. `SequenceCaster` buffers input and resolves sequences; `SpellInvoker` validates and executes commands; each `SpellCommand` owns its behavior, temporary state, and lifetime.
- Keep shared configuration resources such as `SpellDefinition` free of runtime state. Instantiate spell commands for accepted casts.
- Complete or fail every spell command through its lifecycle API and free it afterward. A launched projectile owns its movement, collisions, lifetime, and destruction independently of the command that created it.
- Keep health, death behavior, movement, and presentation in focused components with clear responsibilities.

# Effects and entity reactions

- Exchange effects through data objects such as `ActionData` and `AttackData`. Keep these contracts small and add fields when required by concrete behavior.
- Spells and contact effects construct and dispatch effect data. Receivers route it to compatible composed reactions, and those reactions own the affected entity's response.
- Apply damage through the attack receiver/reaction pipeline and `Health`; apply push or knockback through the action receiver/reaction pipeline and the appropriate movement or physics component.
- Unsupported effects should be ignored safely. Avoid coupling effect producers to a target's concrete player or enemy script.

# Dependencies and public APIs

- Provide dependencies through exported references, explicit setup methods, or context objects such as `SpellContext`.
- Avoid hard-coded paths outside a component's composed scene and arbitrary scene-tree searches. Use groups for discovery where required by the feature, such as identifying player targets.
- Expose narrow capabilities such as `try_spell_jump()` so commands can request behavior through the entity's public API. Keep movement-mode coordination in the entity and the actual movement behavior in its composed components.

# State ownership and presentation

- Give each gameplay state one authoritative owner. `SpellDatabase` catalogues shared spell definitions; `SpellRegistry` owns one player's spell availability; `SpellCooldowns` owns cooldown state; `SwitchComponent` owns switch state.
- Treat lookups and UI data as derived views. Update them from the owning system rather than maintaining another independent source of gameplay state.
- Keep per-entity runtime state separate from shared resources so changing one entity does not affect another.
- UI observes gameplay state and calls public APIs to request changes. Presentation must not control gameplay cooldowns or infer spell artwork from input sequences.
- Connect consumers to state-change signals and initialize their presentation from current authoritative state. Emit change signals after state changes, and avoid emitting them again for idempotent requests.

# Configuration, failures, and cleanup

- Export gameplay tuning values and component references so they can be configured in scenes. Keep presentation settings configurable without changing gameplay logic.
- Validate required dependencies and report clear configuration errors. Handle missing or invalid data safely.
- Rejected operations must not apply effects or change unrelated state. For example, a cooldown rejection must not restart its timer or create another HUD entry.
- Deduplicate hits, continuous contact effects, and lifecycle events as required by the feature rules.
- Free temporary commands, projectiles, and UI entries when their lifecycle ends. Handle removed targets and signal dependencies safely.
- Apply physics collision changes with deferred updates when required by physics callbacks, and preserve feature safety rules such as checking doorway occupancy before restoring collision.

# Specs and verification

- Write behavior-focused specs with a feature overview, behavior rules, scene composition, component responsibility table, public contracts, failure handling, scope limits, implementation plan, and acceptance criteria. Include goals, testing requirements, and sequence or state diagrams where useful.
- Define behavior and edge cases before implementation, including rejection behavior and interactions with existing components.
- Verify focused components independently before testing the full gameplay pipeline. Add automated coverage for meaningful behavior, integration boundaries, lifecycle handling, and acceptance criteria.
- Existing automated suites use standalone `SceneTree` scripts and headless runners under `tests/`. Follow the relevant suite's conventions when extending coverage.
- Manually verify visual presentation and physics interactions where automated checks do not establish the complete acceptance behavior.

# Naming conventions

- Scene files (`.tscn`) use PascalCase (upper CamelCase), matching their root node or primary role, such as `PlayerHud.tscn` and `MagicArrowSpell.tscn`.
- Scene node names and GDScript classes use PascalCase.
- Directories, GDScript files, resource files, and asset files use lowercase snake_case.
- Variables, functions, parameters, and signals use snake_case.
- Constants use SCREAMING_SNAKE_CASE.
