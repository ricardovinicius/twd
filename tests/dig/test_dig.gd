extends SceneTree

const SPELL_DATABASE := preload("res://spells/spell_database.tres")

var player_scene: PackedScene
var block_scene: PackedScene

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	player_scene = load("res://entities/player/Player.tscn")
	block_scene = load("res://entities/interactive/diggable_block/DiggableBlock.tscn")

	await process_frame

	_test_definition()
	await _test_reaction_breaks_block_in_one_hit()
	await _test_reaction_ignores_other_actions()
	await _test_player_cast_breaks_block()
	await _test_push_does_not_break_block()
	await _test_level_wiring()

	if _failures.is_empty():
		print("PASS: dig (%d checks)" % _checks)
		quit(0)
		return

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	print("FAIL: dig (%d failures, %d checks)" % [_failures.size(), _checks])
	quit(1)


func _test_definition() -> void:
	var database := SPELL_DATABASE as SpellDatabase
	var spell := database.get_spell(&"dig")

	_check(spell != null, "The database must contain the dig spell.")
	if spell == null:
		return

	_check(
		spell.sequence == [&"attack", &"interaction"],
		"Dig must use the attack + interaction (J + K) sequence."
	)
	_check(spell.command_scene != null, "Dig must have a command scene.")


func _test_reaction_breaks_block_in_one_hit() -> void:
	var block := block_scene.instantiate() as Node2D
	root.add_child(block)
	await process_frame

	var receiver := block.get_node("ActionReceiver") as ActionReceiver
	var action := _create_action(&"dig", 1.0)
	receiver.receive_action(action)

	_check(
		block.is_queued_for_deletion(),
		"A single dig action must break a diggable block."
	)

	await _free_node(block)


func _test_reaction_ignores_other_actions() -> void:
	var block := block_scene.instantiate() as Node2D
	root.add_child(block)
	await process_frame

	var receiver := block.get_node("ActionReceiver") as ActionReceiver
	var ignored_count := [0]
	receiver.action_ignored.connect(
		func(_action: ActionData) -> void: ignored_count[0] += 1
	)

	receiver.receive_action(_create_action(&"push", 200.0))
	receiver.receive_action(_create_action(&"dig", 0.0))

	_check(not block.is_queued_for_deletion(), "Non-dig actions must not break the block.")
	_check(ignored_count[0] == 2, "Unsupported actions must be ignored safely.")

	await _free_node(block)


func _test_player_cast_breaks_block() -> void:
	var setup := await _spawn_player_facing_block()
	var player: Node2D = setup[0]
	var block: Node2D = setup[1]
	var caster: SequenceCaster = player.get_node("SequenceCaster")

	caster._add_token_to_sequence(&"attack")
	caster._add_token_to_sequence(&"interaction")
	caster.confirm_sequence()

	_check(
		not is_instance_valid(block) or block.is_queued_for_deletion(),
		"Casting J + K and confirming with I must break the block in front of the player."
	)

	await _free_node(block)
	await _free_node(player)


func _test_push_does_not_break_block() -> void:
	var setup := await _spawn_player_facing_block()
	var player: Node2D = setup[0]
	var block: Node2D = setup[1]
	var caster: SequenceCaster = player.get_node("SequenceCaster")

	caster._add_token_to_sequence(&"interaction")
	caster.confirm_sequence()

	_check(
		is_instance_valid(block) and not block.is_queued_for_deletion(),
		"Push must not break a diggable block."
	)

	await _free_node(block)
	await _free_node(player)


func _test_level_wiring() -> void:
	var level_scene := load("res://levels/level_01/Level01.tscn") as PackedScene
	var level := level_scene.instantiate()
	var block_count := 0

	for child in level.get_children():
		if child.scene_file_path == block_scene.resource_path:
			block_count += 1

	_check(block_count == 5, "Level 01 must place the five diggable blocks.")

	var tile_layer := level.get_node("TileMapPrincipal1") as TileMapLayer
	_check(
		tile_layer.get_used_cells_by_id(4).is_empty(),
		"Yellow blocks must not remain as static tiles."
	)

	var second_layer := level.get_node("TileMapPrincipal2") as TileMapLayer
	_check(
		second_layer.get_used_cells().is_empty(),
		"Yellow blocks must not remain as tiles on the second tile layer."
	)

	level.free()


func _spawn_player_facing_block() -> Array[Node2D]:
	var player := player_scene.instantiate() as Node2D
	root.add_child(player)
	player.global_position = Vector2.ZERO
	player.set_physics_process(false)

	# Dig is sold at checkpoints, so the fixture unlocks it directly.
	var registry: SpellRegistry = player.get_node("SpellRegistry")
	registry.register_spell(&"dig")

	var block := block_scene.instantiate() as Node2D
	root.add_child(block)
	block.global_position = Vector2(100.0, 0.0)

	await process_frame
	await physics_frame
	await physics_frame

	var nodes: Array[Node2D] = [player, block]

	return nodes


func _create_action(type: StringName, strength: float) -> ActionData:
	var action := ActionData.new()

	action.type = type
	action.direction = Vector2.RIGHT
	action.strength = strength

	return action


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)


func _free_node(node: Node) -> void:
	if not is_instance_valid(node):
		return

	node.queue_free()
	await process_frame
