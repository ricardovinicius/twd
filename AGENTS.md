# Overview

- In this project is a game in Godot engine.

# Patterns

- Composition-over-inheritance: Use composition over inheritance to create flexible and reusable components. Instead of creating a deep inheritance hierarchy, favor composing objects with smaller, focused components that can be combined to achieve the desired behavior.

# Naming conventions

- Scene files (`.tscn`) use PascalCase (upper CamelCase), matching their root node or primary role, such as `PlayerHud.tscn` and `MagicArrowSpell.tscn`.
- Scene node names and GDScript classes use PascalCase.
- Directories, GDScript files, resource files, and asset files use lowercase snake_case.
- Variables, functions, parameters, and signals use snake_case.
- Constants use SCREAMING_SNAKE_CASE.
