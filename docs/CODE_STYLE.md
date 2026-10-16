# Code Style

Follow these preferences when writing or changing GDScript. They establish the style for new work; existing files may contain older formatting. Keep formatting changes focused on the code being changed unless a broader cleanup is requested.

Project organization, component boundaries, and state ownership follow [AGENTS.md](../AGENTS.md). Logging follows [LOGGING.md](LOGGING.md).

## Whitespace and Semantic Blocks

- Use tabs for GDScript indentation and UTF-8 encoding.
- Separate function definitions with two blank lines. Also use two blank lines between script-level declarations and the first function.
- Use one blank line between semantic code blocks inside a function. Each block should represent one coherent step, such as validation, preparation, applying changes, publishing signals, or returning a result.
- Keep related statements together within a block. Do not insert blank lines between every assignment or statement.
- Separate independent guard clauses with a blank line, and leave a blank line after validation before the main operation.
- Use spaces around assignment, arithmetic, and comparison operators, and after commas and type annotation colons.
- Keep blank lines empty, remove trailing whitespace from changed lines, and end files with a newline.

For example, validation, object creation, configuration, and returning the result are distinct semantic blocks:

```gdscript
func _create_action_for(_receiver: ActionReceiver) -> ActionData:
	if context == null:
		return null

	var action := ActionData.new()

	action.type = &"push"
	action.source = context.caster
	action.origin = context.origin
	action.direction = context.direction.normalized()
	action.strength = push_strength

	return action
```

Use this spacing to make the sequence of operations easy to scan. A short function that performs one coherent operation does not need an internal blank line.

## Naming and Script Layout

- Put `class_name` before `extends` when a script declares a named class.
- Use PascalCase for GDScript classes and scene node names.
- Use lowercase snake_case for directories, scripts, resources, and asset filenames. Scene filenames use PascalCase, matching their root node or primary role.
- Use snake_case for variables, parameters, functions, and signals; use SCREAMING_SNAKE_CASE for constants.
- Prefix internal helpers and private runtime state with `_`. Name signal callbacks `_on_*` to identify the event they handle.
- Use descriptive English identifiers. Prefer names that explain the value or operation over abbreviations.
- Group related signals, constants, exported settings, node references, and runtime state. Keep their ordering consistent within the script; no universal declaration order is required beyond `class_name` and `extends`.

## Types and Expressions

- Explicitly type function parameters and return values, including `-> void`.
- Explicitly type exported settings, component references, and public data contracts. Use typed collections when their element types are known.
- Prefer `:=` for local variables when the expression clearly supplies the intended type. Use an explicit type when inference is ambiguous or a narrower contract improves clarity.
- Use descriptive intermediate variables to name meaningful calculations or decisions. Favor readable steps over densely nested expressions.
- Create data objects and assign related properties together before dispatching or returning them.
- Use double-quoted strings. Use `StringName` values where required by a typed contract; this guide does not require converting every string literal to `&"..."`.

## Wrapping

- Keep short signatures and calls on one line when they are easy to read.
- Wrap longer signatures and calls with one parameter or argument per line. Indent continuation lines by one tab and align the closing parenthesis with the start of the statement.
- Wrap complex boolean expressions in parentheses, with one meaningful condition per line and continuation operators at the beginning of subsequent lines.
- Wrap for readability rather than enforcing an arbitrary maximum line length.

```gdscript
func calculate_velocity(
	current_velocity: float,
	input_direction: float,
	delta: float
) -> float:
	var target_velocity := input_direction * max_speed

	return move_toward(current_velocity, target_velocity, acceleration * delta)


func _is_changing_direction(
	current_velocity: float,
	input_direction: float
) -> bool:
	return (
		not is_zero_approx(current_velocity)
		and signf(current_velocity) != signf(input_direction)
	)
```

## Control Flow and Comments

- Validate prerequisites with guard clauses and early returns. Keep the successful path shallow and readable.
- Use small, named helper methods for meaningful operations or decisions. Component extraction and entity coordination follow the composition rules in `AGENTS.md`.
- Write comments in English to explain intent, constraints, or non-obvious behavior. Avoid narrating statements that are already clear.
- Use `##` documentation comments for exported configuration that needs an explanation. Group related Inspector settings with `@export_category` and use ranges where appropriate.
- Prefer semantic spacing and named helpers to decorative comment separators. Guard-clause banners are not required.
- Follow the logging policy for diagnostics; older logging formats are not style precedents.
