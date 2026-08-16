extends SceneTree

const COOLDOWN_ENTRY_SCENE := preload("res://spells/ui/CooldownEntry.tscn")
const COOLDOWN_UI_SCENE := preload("res://spells/ui/CooldownUI.tscn")
const PLAYER_SCENE := preload("res://entities/player/Player.tscn")
const DASH_DEFINITION := preload("res://spells/dash/dash_spell_definition.tres")
const PUSH_DEFINITION := preload("res://spells/action/push/push_spell_definition.tres")
const MAGIC_ARROW_DEFINITION := preload(
	"res://spells/attack/magic_arrow/magic_arrow_definition.tres"
)

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await process_frame

	_test_initial_spell_icons()
	await _test_vertical_overlay_progress()
	await _test_cooldown_lifecycle_and_ordering()
	await _test_rejected_cast_does_not_restart_entry()
	await _test_player_hud_integration()

	if _failures.is_empty():
		print("PASS: cooldown UI (%d checks)" % _checks)
		quit(0)
		return

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	print("FAIL: cooldown UI (%d failures, %d checks)" % [_failures.size(), _checks])
	quit(1)


func _test_initial_spell_icons() -> void:
	_check(MAGIC_ARROW_DEFINITION.icon != null, "Magic Arrow must have an icon.")
	_check(PUSH_DEFINITION.icon != null, "Push must have an icon.")
	_check(DASH_DEFINITION.icon != null, "Dash must have an icon.")


func _test_vertical_overlay_progress() -> void:
	var entry := COOLDOWN_ENTRY_SCENE.instantiate() as CooldownEntry
	root.add_child(entry)
	await process_frame

	entry.setup(MAGIC_ARROW_DEFINITION, 2.0)
	_check(
		is_equal_approx(entry.cooldown_overlay.anchor_top, 0.0),
		"A new cooldown must fully cover its icon."
	)

	entry.set_remaining(0.5)
	_check(
		is_equal_approx(entry.cooldown_overlay.anchor_top, 0.75),
		"The bottom-anchored overlay must reveal the icon from top to bottom."
	)

	entry.set_remaining(-1.0)
	_check(
		is_equal_approx(entry.cooldown_overlay.anchor_top, 1.0),
		"Cooldown progress must clamp at an empty overlay."
	)

	await _free_node(entry)


func _test_cooldown_lifecycle_and_ordering() -> void:
	var cooldowns := SpellCooldowns.new()
	var cooldown_ui := COOLDOWN_UI_SCENE.instantiate() as CooldownUI
	root.add_child(cooldowns)
	root.add_child(cooldown_ui)
	await process_frame
	cooldown_ui.setup(cooldowns)

	var first_spell := _make_spell(&"first", 0.05, MAGIC_ARROW_DEFINITION.icon)
	var second_spell := _make_spell(&"second", 0.25, DASH_DEFINITION.icon)
	var no_cooldown_spell := _make_spell(&"instant", 0.0, PUSH_DEFINITION.icon)

	cooldowns.start(no_cooldown_spell)
	_check(
		cooldown_ui.cooldown_container.get_child_count() == 0,
		"A zero-duration cooldown must not create an entry."
	)

	cooldowns.start(first_spell)
	cooldowns.start(second_spell)
	await process_frame

	_check(cooldown_ui.visible, "The cooldown UI must become visible for an active cooldown.")
	_check(
		cooldown_ui.cooldown_container.get_child_count() == 2,
		"Two active spell cooldowns must create two entries."
	)
	_check(
		_get_entry_id(cooldown_ui, 0) == first_spell.id,
		"The first accepted cooldown must occupy the first position."
	)
	_check(
		_get_entry_id(cooldown_ui, 1) == second_spell.id,
		"The second accepted cooldown must occupy the second position."
	)

	# A defensive duplicate start refreshes the existing entry without changing order.
	cooldown_ui._on_cooldown_started(first_spell, first_spell.cooldown)
	_check(
		cooldown_ui.cooldown_container.get_child_count() == 2,
		"A duplicate start signal must not create a duplicate entry."
	)
	_check(
		_get_entry_id(cooldown_ui, 0) == first_spell.id,
		"Refreshing an existing entry must preserve its casting-order position."
	)

	await create_timer(0.1).timeout
	_check(cooldown_ui.get_entry(first_spell.id) == null, "A finished cooldown must be removed.")
	_check(
		_get_entry_id(cooldown_ui, 0) == second_spell.id,
		"Later cooldowns must reflow without changing relative order."
	)

	await create_timer(0.2).timeout
	_check(cooldown_ui.get_entry(second_spell.id) == null, "The final entry must be removed.")
	_check(not cooldown_ui.visible, "The cooldown UI must hide when it becomes empty.")

	await _free_node(cooldown_ui)
	await _free_node(cooldowns)


func _test_player_hud_integration() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	var cooldowns: SpellCooldowns = player.get_node("SpellCooldowns")
	var hud: PlayerHud = player.get_node("PlayerHudLayer/PlayerHud")
	var cooldown_ui: CooldownUI = hud.get_node("CooldownUI")

	_check(hud.cooldowns == cooldowns, "PlayerHud must use the player's SpellCooldowns component.")
	_check(
		cooldown_ui.cooldowns == cooldowns,
		"The composed CooldownUI must receive the PlayerHud cooldown dependency."
	)

	cooldowns.start(MAGIC_ARROW_DEFINITION)
	await process_frame
	var entry := cooldown_ui.get_entry(MAGIC_ARROW_DEFINITION.id)
	_check(entry != null, "Starting a player spell cooldown must add a HUD entry.")
	if entry != null:
		_check(
			entry.spell_icon.texture == MAGIC_ARROW_DEFINITION.icon,
			"The HUD entry must use the spell's configured representative icon."
		)

	await _free_node(player)


func _test_rejected_cast_does_not_restart_entry() -> void:
	var cooldowns := SpellCooldowns.new()
	var invoker := SpellInvoker.new()
	var cooldown_ui := COOLDOWN_UI_SCENE.instantiate() as CooldownUI
	invoker.cooldowns = cooldowns
	root.add_child(cooldowns)
	root.add_child(invoker)
	root.add_child(cooldown_ui)
	await process_frame
	cooldown_ui.setup(cooldowns)

	var spell := MAGIC_ARROW_DEFINITION.duplicate() as SpellDefinition
	spell.id = &"rejected_spell"
	spell.cooldown = 0.25
	var start_count := [0]
	var rejection_count := [0]
	cooldowns.cooldown_started.connect(
		func(_spell: SpellDefinition, _duration: float) -> void: start_count[0] += 1
	)
	invoker.spell_rejected.connect(
		func(_spell: SpellDefinition, _reason: StringName) -> void: rejection_count[0] += 1
	)

	cooldowns.start(spell)
	var rejected_command := invoker.cast(spell, SpellContext.new())
	await process_frame

	_check(rejected_command == null, "An active cooldown must reject another cast.")
	_check(rejection_count[0] == 1, "A cooldown-blocked cast must emit one rejection.")
	_check(start_count[0] == 1, "A rejected cast must not restart the cooldown lifecycle.")
	_check(
		cooldown_ui.cooldown_container.get_child_count() == 1,
		"A rejected cast must not create another cooldown entry."
	)

	await _free_node(cooldown_ui)
	await _free_node(invoker)
	await _free_node(cooldowns)


func _make_spell(spell_id: StringName, duration: float, icon: Texture2D) -> SpellDefinition:
	var spell := SpellDefinition.new()
	spell.id = spell_id
	spell.display_name = String(spell_id)
	spell.cooldown = duration
	spell.icon = icon
	return spell


func _get_entry_id(cooldown_ui: CooldownUI, index: int) -> StringName:
	if index < 0 or index >= cooldown_ui.cooldown_container.get_child_count():
		return &""

	var entry := cooldown_ui.cooldown_container.get_child(index) as CooldownEntry
	return entry.spell_id if entry != null else &""


func _free_node(node: Node) -> void:
	if not is_instance_valid(node):
		return

	node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
