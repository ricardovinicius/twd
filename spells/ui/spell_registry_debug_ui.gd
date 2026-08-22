class_name SpellRegistryDebugUI
extends Control

@onready var catalogued_spell_list: VBoxContainer = %CataloguedSpellList
@onready var registered_spell_list: VBoxContainer = %RegisteredSpellList
@onready var status_label: Label = %StatusLabel

var registry: SpellRegistry
var _register_buttons: Dictionary[StringName, Button] = {}
var _unregister_buttons: Dictionary[StringName, Button] = {}


func setup(spell_registry: SpellRegistry) -> void:
	if registry == spell_registry:
		_refresh()
		return

	_disconnect_registry()
	registry = spell_registry

	if registry == null:
		status_label.text = "SpellRegistry is not assigned."
		_refresh()
		return

	registry.spell_registered.connect(_on_registry_changed)
	registry.spell_unregistered.connect(_on_registry_changed)
	_refresh()


func get_register_button(spell_id: StringName) -> Button:
	return _register_buttons.get(spell_id) as Button


func get_unregister_button(spell_id: StringName) -> Button:
	return _unregister_buttons.get(spell_id) as Button


func get_catalogued_spell_count() -> int:
	return catalogued_spell_list.get_child_count()


func get_registered_spell_count() -> int:
	return registered_spell_list.get_child_count()


func _exit_tree() -> void:
	_disconnect_registry()


func _refresh() -> void:
	_clear_list(catalogued_spell_list)
	_clear_list(registered_spell_list)
	_register_buttons.clear()
	_unregister_buttons.clear()

	if registry == null:
		status_label.text = "SpellRegistry is not assigned."
		return

	if registry.database == null:
		status_label.text = "SpellDatabase is not assigned."
		return

	status_label.text = "Changes apply immediately to the player."
	for spell in registry.database.get_spells():
		var register_button := _add_spell_row(
			catalogued_spell_list,
			spell,
			"Register",
			registry.has_spell(spell.id)
		)
		register_button.pressed.connect(_on_register_pressed.bind(spell.id))
		_register_buttons[spell.id] = register_button

	for spell in registry.get_registered_spells():
		var unregister_button := _add_spell_row(
			registered_spell_list,
			spell,
			"Remove",
			false
		)
		unregister_button.pressed.connect(_on_unregister_pressed.bind(spell.id))
		_unregister_buttons[spell.id] = unregister_button


func _add_spell_row(
	container: VBoxContainer,
	spell: SpellDefinition,
	button_text: String,
	button_disabled: bool
) -> Button:
	var row := HBoxContainer.new()
	row.name = "%sRow" % String(spell.id).to_pascal_case()
	row.add_theme_constant_override("separation", 6)
	container.add_child(row)

	if spell.icon != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = spell.icon
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "%s  [%s]  %s" % [
		spell.display_name,
		spell.id,
		_format_sequence(spell.sequence),
	]
	label.tooltip_text = spell.description
	row.add_child(label)

	var button := Button.new()
	button.text = button_text
	button.disabled = button_disabled
	row.add_child(button)
	return button


func _format_sequence(sequence: Array[StringName]) -> String:
	var tokens := PackedStringArray()
	for token in sequence:
		tokens.append(String(token).capitalize())
	return " + ".join(tokens)


func _clear_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _disconnect_registry() -> void:
	if registry == null:
		return

	if registry.spell_registered.is_connected(_on_registry_changed):
		registry.spell_registered.disconnect(_on_registry_changed)
	if registry.spell_unregistered.is_connected(_on_registry_changed):
		registry.spell_unregistered.disconnect(_on_registry_changed)

	registry = null


func _on_register_pressed(spell_id: StringName) -> void:
	if registry != null:
		registry.register_spell(spell_id)


func _on_unregister_pressed(spell_id: StringName) -> void:
	if registry != null:
		registry.unregister_spell(spell_id)


func _on_registry_changed(_spell: SpellDefinition) -> void:
	_refresh()
