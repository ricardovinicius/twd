extends SceneTree

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_command_failure_lifecycle()
	await _test_projectile_parent()
	await _test_player_projectile_world_space()
	await _test_cooldown_reconnection()
	await _test_invalid_action_and_inventory()
	await _test_equipment_mutations()
	await _test_main_dependencies()
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	if _failures.is_empty():
		print("PASS: standards regressions (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_command_failure_lifecycle() -> void:
	var invoker := SpellInvoker.new()
	root.add_child(invoker)
	var definition := SpellDefinition.new()
	definition.command_scene = load("res://spells/double_jump/DoubleJumpSpell.tscn")
	var failures: Array = []
	invoker.spell_failed.connect(
		func(spell: SpellDefinition, command: SpellCommand, reason: StringName) -> void:
			failures.append([spell, command, reason])
	)
	var command := invoker.cast(definition, SpellContext.new())
	_check(failures.size() == 1, "Invoker must report a command failure exactly once.")
	if failures.size() == 1:
		_check(failures[0] == [definition, command, &"missing_caster"], "Failure metadata must retain its argument order.")
	command.cancel()
	command.complete()
	_check(failures.size() == 1, "A terminated command must not emit another lifecycle event.")
	await process_frame
	_check(not is_instance_valid(command), "Failed commands must free themselves.")
	await _free_node(invoker)


func _test_projectile_parent() -> void:
	var caster_parent := Node2D.new()
	var caster := Node2D.new()
	caster_parent.add_child(caster)
	root.add_child(caster_parent)
	var effects := Node2D.new()
	root.add_child(effects)
	var scene: PackedScene = load("res://spells/attack/magic_arrow/MagicArrowSpell.tscn")
	var spell := scene.instantiate() as MagicArrowSpell
	root.add_child(spell)
	var context := SpellContext.new()
	context.caster = caster
	context.effect_parent = effects
	context.direction = Vector2.RIGHT
	spell.execute(context)
	_check(effects.get_child_count() == 1, "The projectile must use the explicit effect parent.")
	_check(caster_parent.get_child_count() == 1, "The projectile must not depend on the caster's parent.")
	await _free_node(effects)
	await _free_node(caster_parent)


func _test_player_projectile_world_space() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player_scene: PackedScene = load("res://entities/player/Player.tscn")
	var player := player_scene.instantiate() as CharacterBody2D
	player.set_physics_process(false)
	world.add_child(player)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0.0, 80.0)
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000.0, 20.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	world.add_child(floor_body)
	await physics_frame
	await process_frame

	var caster: SequenceCaster = player.get_node("SequenceCaster")
	caster.current_sequence.append(&"attack")
	caster.confirm_sequence()
	var projectile: MagicArrowProjectile
	for child in player.get_children():
		if child is MagicArrowProjectile:
			projectile = child
	_check(projectile != null, "Player casting must create a Magic Arrow under its configured effect parent.")
	if projectile == null:
		await _free_node(world)
		return
	_check(projectile.global_scale.is_equal_approx(Vector2(3.0, 3.0)), "The projectile must retain its scene scale instead of inheriting player scale.")
	var origin := projectile.global_position
	player.position += Vector2(120.0, -80.0)
	player.rotation = 0.5
	_check(projectile.global_position.is_equal_approx(origin), "Moving the caster must not move an already launched projectile.")
	_check(is_zero_approx(projectile.global_rotation), "Rotating the caster must not rotate an already launched projectile.")
	player.position = Vector2.ZERO
	player.rotation = 0.0
	await physics_frame
	await physics_frame
	await process_frame
	_check(is_instance_valid(projectile), "A horizontal arrow above a floor must not collide because of inherited caster scale.")
	if is_instance_valid(projectile):
		_check(projectile.global_position.x > origin.x, "The arrow must advance along its cast direction.")
		_check(is_equal_approx(projectile.global_position.y, origin.y), "The arrow's height must remain independent of caster movement.")
	await _free_node(world)


func _test_cooldown_reconnection() -> void:
	var cooldowns := SpellCooldowns.new()
	root.add_child(cooldowns)
	var definition: SpellDefinition = load("res://spells/dash/dash_spell_definition.tres").duplicate()
	definition.cooldown = 1.0
	var second := definition.duplicate() as SpellDefinition
	second.id = &"second"
	cooldowns.start(definition)
	cooldowns.start(second)
	await create_timer(0.05).timeout
	var scene: PackedScene = load("res://spells/ui/CooldownUI.tscn")
	var ui := scene.instantiate() as CooldownUI
	root.add_child(ui)
	ui.setup(cooldowns)
	_check(ui.get_entry(definition.id) != null, "A late HUD must display an active cooldown.")
	_check(ui.get_entry(second.id) != null, "A late HUD must display every active cooldown.")
	var entry := ui.get_entry(definition.id)
	if entry != null:
		_check(entry.get_index() == 0, "Reconstructed entries must preserve start order.")
		_check(entry.cooldown_overlay.anchor_top > 0.0, "A reconstructed entry must show elapsed progress.")
	var remaining := cooldowns.get_remaining(definition.id)
	cooldowns.start(definition)
	_check(cooldowns.get_remaining(definition.id) <= remaining, "Starting an active cooldown must not extend it.")
	ui.setup(null)
	await process_frame
	ui.setup(cooldowns)
	_check(ui.get_entry(definition.id) != null, "Reconnecting a HUD must reconstruct active entries.")
	_check(cooldowns.get_remaining(definition.id) <= remaining, "HUD reconnection must not extend gameplay cooldowns.")
	await _free_node(ui)
	await _free_node(cooldowns)


func _test_invalid_action_and_inventory() -> void:
	var receiver := ActionReceiver.new()
	root.add_child(receiver)
	var ignored: Array = []
	receiver.action_ignored.connect(func(action): ignored.append(action))
	receiver.receive_action(null)
	_check(ignored == [null], "A null action must be ignored safely once.")
	var inventory := Inventory.new()
	root.add_child(inventory)
	var item := ItemDefinition.new()
	item.id = &"test_item"
	_check(not inventory.add_item(null), "Null items must be rejected.")
	_check(not inventory.add_item(item, 0), "Zero item quantities must be rejected.")
	_check(not inventory.add_item(item, -1), "Negative item quantities must be rejected.")
	_check(inventory.get_items().is_empty(), "Rejected additions must not mutate inventory.")
	_check(inventory.add_item(item, 2), "Positive item quantities must be accepted.")
	_check(inventory.has_item(item.id), "Accepted items must be queryable by ID.")
	var snapshot := inventory.get_items()
	snapshot.clear()
	_check(inventory.get_quantity(item) == 2, "An inventory snapshot must not expose mutable state.")
	await _free_node(receiver)
	await _free_node(inventory)


func _test_equipment_mutations() -> void:
	var fixture := Node.new()
	var stats := PlayerStats.new()
	var health := Health.new()
	var movement := HorizontalMovementComponent.new()
	var equipment := Equipment.new()
	equipment.stats = stats
	equipment.health = health
	equipment.horizontal_movement = movement
	for child in [stats, health, movement, equipment]:
		fixture.add_child(child)
	root.add_child(fixture)
	var changes: Array = []
	equipment.equipment_changed.connect(func(slot, item): changes.append([slot, item]))
	var item := ItemDefinition.new()
	item.bonus_move_speed = 50.0
	_check(equipment.equip(0, item), "A new equipment assignment must succeed.")
	_check(equipment.get_item(0) == item, "Equipment queries must return the assigned item.")
	_check(is_equal_approx(movement.max_speed, stats.base_move_speed + 50.0), "Equipping must update movement bonuses.")
	_check(not equipment.equip(0, item), "Equipping the same item must be an idempotent no-op.")
	_check(changes.size() == 1, "An unchanged slot must not emit another signal.")
	equipment.unequip(0)
	equipment.unequip(0)
	_check(changes.size() == 2, "Repeated unequip must emit only one state change.")
	_check(is_equal_approx(movement.max_speed, stats.base_move_speed), "Unequipping must restore base movement speed.")
	await _free_node(fixture)


func _test_main_dependencies() -> void:
	var scene: PackedScene = load("res://Main.tscn")
	var main := scene.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	var registry: SpellRegistry = main.get_node("LevelRoot/Player/SpellRegistry")
	# Untyped: PauseMenu uses autoloads, which are not registered when tests compile.
	var menu = main.get_node("PauseMenuLayer/PauseMenu")
	_check(menu.spell_registry == registry, "Main must supply its player's spell registry.")
	_check(menu.spell_registry_debug_ui.registry == registry, "The registry window must observe that registry.")
	_check(menu.equipment != null, "Main must supply equipment dependencies.")
	_check(menu.inventory != null and menu.stats != null and menu.health != null, "Main must supply inventory, stats, and health.")
	await _free_node(main)


func _free_node(node: Node) -> void:
	node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
