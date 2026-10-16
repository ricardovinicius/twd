# Logging

Use Godot's built-in `push_error()`, `push_warning()`, and `print()` directly. This policy applies to new and changed code; existing logging still needs cleanup in some features.

## Severity and expected outcomes

| Method | Use |
| --- | --- |
| `push_error()` | Broken configuration, invalid required dependencies, or violated programming contracts. |
| `push_warning()` | Unexpected but recoverable conditions that need developer attention. |
| `print()` behind a debug flag | Optional gameplay traces, such as collision details or spell execution. |
| No log | Expected gameplay outcomes, such as cooldown rejection, invalid input sequences, missing targets, or safely ignored unsupported effects. |

Use return values, lifecycle results, signals, and UI feedback to communicate expected outcomes where needed. Routine spell execution and sequence failures do not warrant warnings. Distinguish an expected missing target from a missing required scene dependency, which is a configuration error.

Logging does not replace safe failure handling. After reporting invalid configuration, reject the operation or disable the affected behavior without applying partial effects or changing unrelated state.

## Message format and frequency

Use `ComponentName: Description` and include relevant IDs or values when they help identify the cause. Include an instance ID when distinguishing multiple instances is useful.

```gdscript
push_error("SpellInvoker: Spell '%s' has no command scene." % spell.id)
push_warning("CooldownEntry: Spell '%s' has no representative icon." % spell.id)
```

Report a failure at the component that owns its validation. Avoid reporting the same failure again at each caller. Validate stable scene dependencies during setup where possible, and avoid repeating unchanged errors or warnings in frame or physics loops.

## Debug tracing

Keep optional tracing local to the feature or component, with exported debug flags disabled by default in scripts and committed scenes/resources. Use focused names such as `debug_collisions` so traces can be enabled selectively in the Inspector.

```gdscript
@export_category("Debug")
@export var debug_collisions: bool = false


func _debug_log(message: String) -> void:
	if not debug_collisions:
		return
	print("MagicArrowProjectile: instance=%d %s" % [get_instance_id(), message])
```

Prefer tracing transitions and meaningful events. Avoid per-frame or continuous-contact output unless it is specifically needed for an investigation. Debug flags must not change gameplay behavior. Keep routine traces disabled in release configurations; retain errors and warnings for actionable failures.

## Automated tests

Test harness output is an exception to the debug-flag and component-prefix rules. Preserve the existing `PASS:`/`FAIL:` output and failure reporting used by the standalone suites. See [TESTING.md](TESTING.md) for log locations and runner error detection.

## Adoption and future changes

As existing features are updated, move routine spell execution and sequence failures out of warnings, and put unconditional combat/action traces behind debug flags. Preserve actionable configuration diagnostics and the test runners' output contract.

Keep using the built-in methods until a concrete need arises for centralized filtering, multiple output destinations, or structured logs. Introduce a shared logger only when those requirements justify it.
