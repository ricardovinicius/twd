extends SceneTree

const PLAYER_SCENE := preload("res://entities/player/Player.tscn")
const PAUSE_MENU_SCENE := preload("res://ui/pause_menu/PauseMenu.tscn")
const SPELL_DATABASE := preload("res://spells/spell_database.tres")

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await process_frame

	_test_database_queries_and_copying()
	await _test_registry_mutations_and_signals()
	await _test_registries_are_independent()
	await _test_player_casting_and_cooldown_integration()
	await _test_debug_ui_controls()

	if _failures.is_empty():
		print("PASS: spell registry (%d checks)" % _checks)
		quit(0)
		return

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	print("FAIL: spell registry (%d failures, %d checks)" % [_failures.size(), _checks])
	quit(1)


func _test_database_queries_and_copying() -> void:
	var database := SPELL_DATABASE as SpellDatabase
	var database_spells := database.get_spells()

	_check(database_spells.size() == 3, "The spell database must contain all three spells.")
	_check(
		database.get_spell(&"magic_arrow") == database_spells[0],
		"Database lookup must return the canonical spell definition."
	)
	_check(database.has_spell(&"push"), "The database must find a known spell ID.")
	_check(not database.has_spell(&"unknown"), "The database must reject an unknown spell ID.")

	database_spells.clear()
	_check(
		database.get_spells().size() == 3,
		"Mutating a returned spell list must not mutate the database."
	)


func _test_registry_mutations_and_signals() -> void:
	var registry := SpellRegistry.new()
	registry.database = SPELL_DATABASE
	registry.initial_spell_ids = [&"magic_arrow"]
	root.add_child(registry)
	await process_frame

	var registered_ids: Array[StringName] = []
	var unregistered_ids: Array[StringName] = []
	registry.spell_registered.connect(
		func(spell: SpellDefinition) -> void: registered_ids.append(spell.id)
	)
	registry.spell_unregistered.connect(
		func(spell: SpellDefinition) -> void: unregistered_ids.append(spell.id)
	)

	_check(registry.has_spell(&"magic_arrow"), "Starting spell IDs must initialize the registry.")
	_check(registry.register_spell(&"push"), "A known unregistered spell must be registered.")
	_check(registered_ids == [&"push"], "Registration must emit once after state changes.")
	_check(not registry.register_spell(&"push"), "Registering a duplicate spell must be a no-op.")
	_check(registered_ids.size() == 1, "Duplicate registration must not emit another signal.")
	_check(
		not registry.register_spell(&"unknown"),
		"A spell outside the database must not be registered."
	)
	_check(registry.unregister_spell(&"magic_arrow"), "A registered spell must be removable.")
	_check(
		unregistered_ids == [&"magic_arrow"],
		"Unregistration must emit once after state changes."
	)
	_check(
		not registry.unregister_spell(&"magic_arrow"),
		"Unregistering an absent spell must be a no-op."
	)
	_check(
		registry.get_registered_spells().map(func(spell: SpellDefinition): return spell.id) == [&"push"],
		"Registered spells must retain registration order."
	)

	var returned_spells := registry.get_registered_spells()
	returned_spells.clear()
	_check(registry.has_spell(&"push"), "Mutating a returned list must not mutate the registry.")

	await _free_node(registry)


func _test_registries_are_independent() -> void:
	var first_registry := SpellRegistry.new()
	var second_registry := SpellRegistry.new()
	first_registry.database = SPELL_DATABASE
	second_registry.database = SPELL_DATABASE
	root.add_child(first_registry)
	root.add_child(second_registry)
	await process_frame

	first_registry.register_spell(&"dash")
	_check(first_registry.has_spell(&"dash"), "The first registry must contain its added spell.")
	_check(
		not second_registry.has_spell(&"dash"),
		"Changing one registry must not affect another registry using the same database."
	)

	await _free_node(first_registry)
	await _free_node(second_registry)


func _test_player_casting_and_cooldown_integration() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	var registry: SpellRegistry = player.get_node("SpellRegistry")
	var caster: SequenceCaster = player.get_node("SequenceCaster")
	var cooldowns: SpellCooldowns = player.get_node("SpellCooldowns")
	var selected_ids: Array[StringName] = []
	caster.spell_selected.connect(
		func(spell: SpellDefinition) -> void: selected_ids.append(spell.id)
	)

	_check(
		registry.get_registered_spells().size() == 3,
		"The player must start with the existing three-spell loadout."
	)
	registry.unregister_spell(&"magic_arrow")
	_check(
		not caster.sequence_to_spell.has(&"attack"),
		"Unregistering a spell must remove its sequence mapping immediately."
	)
	caster.current_sequence.append(&"attack")
	caster.confirm_sequence()
	_check(selected_ids.is_empty(), "An unregistered sequence must not select a spell.")

	registry.register_spell(&"magic_arrow")
	_check(
		caster.sequence_to_spell.has(&"attack"),
		"Registering a spell must add its sequence mapping immediately."
	)
	caster.current_sequence.append(&"attack")
	caster.confirm_sequence()
	_check(selected_ids == [&"magic_arrow"], "A newly registered spell must be castable immediately.")
	_check(
		not cooldowns.is_ready(registry.get_spell(&"magic_arrow")),
		"Casting a registered spell must start its normal cooldown."
	)

	registry.unregister_spell(&"magic_arrow")
	registry.register_spell(&"magic_arrow")
	_check(
		not cooldowns.is_ready(registry.get_spell(&"magic_arrow")),
		"Removing and re-adding a spell must not bypass its active cooldown."
	)

	await _free_node(player)


func _test_debug_ui_controls() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	var registry: SpellRegistry = player.get_node("SpellRegistry")
	var hud: PlayerHud = player.get_node("PlayerHudLayer/PlayerHud")
	var pause_menu := PAUSE_MENU_SCENE.instantiate() as PauseMenu
	pause_menu.spell_registry = registry
	root.add_child(pause_menu)
	await process_frame

	var debug_ui := pause_menu.spell_registry_debug_ui
	var main_menu_panel := pause_menu.get_node("PanelContainer") as Control
	var registry_window := pause_menu.spell_registry_window

	_check(not pause_menu.visible, "The pause menu must be hidden during gameplay.")
	_check(
		hud.get_node_or_null("SpellRegistryDebugUI") == null,
		"The player HUD must not contain the registry debug UI."
	)
	_check(
		is_equal_approx(registry_window.anchor_left, 0.5)
		and is_equal_approx(registry_window.anchor_right, 0.5)
		and is_equal_approx(registry_window.offset_left, -registry_window.offset_right),
		"The spell registry window must be centered horizontally."
	)
	_check(debug_ui.registry == registry, "The debug UI must receive the player's registry.")
	_check(debug_ui.get_catalogued_spell_count() == 3, "The debug UI must list every database spell.")
	_check(debug_ui.get_registered_spell_count() == 3, "The debug UI must list registered spells.")

	pause_menu.pause_game()
	_check(pause_menu.visible, "Opening the ESC menu must show the pause menu.")
	_check(paused, "Opening the ESC menu must pause the game.")
	_check(main_menu_panel.visible, "The compact menu must be shown when ESC is pressed.")
	_check(
		not registry_window.visible,
		"The registry window must remain hidden until its menu button is pressed."
	)

	pause_menu.spell_registry_button.pressed.emit()
	_check(registry_window.visible, "The Spell Registry button must open the registry window.")
	_check(not main_menu_panel.visible, "Opening the registry window must hide the compact menu.")

	var escape_event := InputEventAction.new()
	escape_event.action = &"pause"
	escape_event.pressed = true
	pause_menu._unhandled_input(escape_event)
	_check(not registry_window.visible, "ESC must close the registry window.")
	_check(main_menu_panel.visible, "ESC must return to the compact pause menu.")
	_check(paused, "Closing the registry window with ESC must keep the game paused.")
	pause_menu.spell_registry_button.pressed.emit()

	_check(
		debug_ui.get_register_button(&"push").disabled,
		"The Register action must be disabled for an already registered spell."
	)

	debug_ui.get_unregister_button(&"push").pressed.emit()
	_check(not registry.has_spell(&"push"), "The Remove action must unregister its spell.")
	_check(debug_ui.get_registered_spell_count() == 2, "The registered list must refresh after removal.")
	_check(
		not debug_ui.get_register_button(&"push").disabled,
		"The Register action must become available after removal."
	)

	debug_ui.get_register_button(&"push").pressed.emit()
	_check(registry.has_spell(&"push"), "The Register action must add its spell.")
	_check(debug_ui.get_registered_spell_count() == 3, "The registered list must refresh after adding.")

	pause_menu.close_spell_registry_button.pressed.emit()
	_check(not registry_window.visible, "The Back button must close the registry window.")
	_check(main_menu_panel.visible, "The Back button must restore the compact pause menu.")

	paused = false
	await _free_node(pause_menu)
	await _free_node(player)


func _free_node(node: Node) -> void:
	if not is_instance_valid(node):
		return

	node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
