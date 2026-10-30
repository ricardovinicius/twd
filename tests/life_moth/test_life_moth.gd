extends SceneTree

const MOTH_SCENE_PATH := "res://entities/enemies/life_moth/LifeMoth.tscn"
const RESPAWNER_SCRIPT_PATH := "res://entities/enemies/respawn/enemy_respawner.gd"
const BESTIARY_PATH := "res://entities/enemies/bestiary/bestiary.tres"
const PLAYER_SPEED := 400.0
const FAR_AWAY := Vector2(9000.0, 0.0)

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_composition()
	await _test_patrol_stays_around_home()
	await _test_flees_when_player_is_close()
	await _test_player_can_catch_it()
	await _test_calms_down_when_player_leaves()
	await _test_death_drops_orb()
	await _test_respawner_restores_moth()
	_test_bestiary_entry()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: life moth (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_composition() -> void:
	var world := _spawn_world()
	var moth := _spawn_moth(world, Vector2.ZERO)
	await process_frame

	var frames := moth.sprite.sprite_frames

	_check(moth.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "The moth must fly without floors.")
	_check(moth.collision_layer == 0 and moth.collision_mask == 1, "The moth must only collide with the world.")
	_check(frames.get_frame_count(&"fly") == 4, "The fly animation must have four frames.")
	_check(frames.get_frame_texture(&"fly", 0).get_size() == Vector2(16.0, 16.0), "Moth frames must be 16x16.")
	_check((moth.get_node("HeldOrb") as CanvasItem).visible, "The moth must hold its orb.")
	_check(moth.find_children("*", "ContactImpactComponent").is_empty(), "The moth must be harmless to touch.")
	_check(moth.flee_speed < PLAYER_SPEED, "The moth must fly slower than the player runs.")

	await _free_node(world)


func _test_patrol_stays_around_home() -> void:
	var world := _spawn_world()
	var moth := _spawn_moth(world, Vector2(200.0, 0.0))
	var min_x := INF
	var max_x := -INF

	for _index in 300:
		await physics_frame
		min_x = minf(min_x, moth.global_position.x)
		max_x = maxf(max_x, moth.global_position.x)

	_check(moth.get_state() == LifeMoth.State.PATROL, "Without a player the moth must patrol.")
	_check(max_x - min_x > moth.patrol_distance, "The moth must flutter from side to side.")
	_check(
		min_x >= 200.0 - moth.patrol_distance - 12.0 and max_x <= 200.0 + moth.patrol_distance + 12.0,
		"The patrol must stay around its spot."
	)

	await _free_node(world)


func _test_flees_when_player_is_close() -> void:
	var world := _spawn_world()
	var moth := _spawn_moth(world, Vector2.ZERO)
	var player := _spawn_player(world, FAR_AWAY)
	await _await_physics_frames(5)

	var start := moth.global_position

	player.global_position = start + Vector2(-140.0, 0.0)
	await _await_physics_frames(3)

	_check(moth.get_state() == LifeMoth.State.FLEE, "A close player must make the moth flee.")
	_check(moth.get_threat() == player, "The moth must flee from the player.")

	await _await_physics_frames(60)

	_check(moth.global_position.x > start.x + 100.0, "The moth must fly away from the player.")
	_check(moth.velocity.length() <= moth.flee_speed + moth.flutter_speed + 1.0, "The moth must not exceed its flee speed.")
	_check(moth.global_position.y >= moth.get_home().y - moth.max_height_offset - 4.0, "The moth must stay in its height band.")

	await _free_node(world)


func _test_player_can_catch_it() -> void:
	var world := _spawn_world()
	var moth := _spawn_moth(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(-150.0, 0.0))
	var caught := false
	var frames := 0

	await _await_physics_frames(2)

	for _index in 360:
		await physics_frame
		frames += 1

		var offset := moth.global_position - player.global_position

		if offset.length() < 30.0:
			caught = true
			break

		player.global_position += offset.normalized() * PLAYER_SPEED / 60.0

	_check(caught, "A player running at full speed must catch the moth.")
	_check(frames > 75, "Catching the moth must take some effort.")

	await _free_node(world)


func _test_calms_down_when_player_leaves() -> void:
	var world := _spawn_world()
	var moth := _spawn_moth(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(-120.0, 0.0))
	await _await_physics_frames(20)

	_check(moth.get_state() == LifeMoth.State.FLEE, "The fixture must start with the moth fleeing.")

	var fled_x := moth.global_position.x

	player.global_position = FAR_AWAY
	await _await_physics_frames(3)

	_check(moth.get_state() == LifeMoth.State.PATROL, "The moth must calm down once the player is gone.")
	_check(absf(moth.get_home().x - fled_x) < 20.0, "The moth must settle where it fled to.")

	await _free_node(world)


func _test_death_drops_orb() -> void:
	var world := _spawn_world()
	var moth := _spawn_moth(world, Vector2(0.0, 0.0))
	await _await_physics_frames(2)

	var hand_position := (moth.get_node("HeldOrb") as Node2D).global_position

	moth.health.take_damage(moth.health.maximum)
	await process_frame
	await process_frame

	var orbs: Array[HealthOrb] = []

	for child in world.get_children():
		if child is HealthOrb:
			orbs.append(child)

	_check(not is_instance_valid(moth), "A dead moth must be freed.")
	_check(orbs.size() == 1, "A dead moth must drop its orb.")
	if orbs.size() == 1:
		_check(orbs[0].global_position.distance_to(hand_position) < 12.0, "The orb must fall from the moth's hand.")
		await _await_until(func() -> bool: return orbs[0].is_released(), 180)
		_check(orbs[0].is_released(), "The dropped orb must land and release its health.")

	await _free_node(world)


func _test_respawner_restores_moth() -> void:
	var world := _spawn_world()
	var respawner := Node2D.new()
	var moth := (load(MOTH_SCENE_PATH) as PackedScene).instantiate() as LifeMoth

	respawner.set_script(load(RESPAWNER_SCRIPT_PATH))
	moth.patrol_distance = 40.0
	moth.position = Vector2(320.0, -50.0)
	respawner.add_child(moth)
	world.add_child(respawner)
	await process_frame

	respawner.respawn_all()
	await _await_physics_frames(2)

	var respawned: LifeMoth = null

	for child in respawner.get_children():
		if child is LifeMoth and child != moth:
			respawned = child

	_check(respawned != null, "The respawner must recreate the moth.")
	if respawned != null:
		_check(is_equal_approx(respawned.patrol_distance, 40.0), "Respawn must keep the patrol distance.")
		_check(respawned.get_home().distance_to(Vector2(320.0, -50.0)) < 2.0, "Respawn must keep the placement.")
		_check((respawned.get_node("HeldOrb") as CanvasItem).visible, "A respawned moth must hold a new orb.")

	await _free_node(world)


func _test_bestiary_entry() -> void:
	var found := false

	for entry in load(BESTIARY_PATH).entries:
		if entry.id == &"life_moth":
			found = true
			_check(entry.portrait != null, "The moth's guide entry must have a portrait.")

	_check(found, "The monster guide must list the moth.")


func _spawn_world() -> Node2D:
	var world := Node2D.new()
	var block := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()

	block.collision_layer = 1
	block.collision_mask = 0
	rectangle.size = Vector2(40000.0, 40.0)
	shape.shape = rectangle
	block.add_child(shape)
	block.position = Vector2(0.0, 220.0)
	world.add_child(block)
	root.add_child(world)
	return world


func _spawn_moth(parent: Node, at: Vector2) -> LifeMoth:
	var moth := (load(MOTH_SCENE_PATH) as PackedScene).instantiate() as LifeMoth

	moth.position = at
	parent.add_child(moth)
	return moth


func _spawn_player(parent: Node, at: Vector2) -> CharacterBody2D:
	var player := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()

	player.collision_layer = 4
	player.collision_mask = 0
	player.add_to_group(&"player")
	rectangle.size = Vector2(30.0, 60.0)
	shape.shape = rectangle
	player.add_child(shape)
	player.position = at
	parent.add_child(player)
	return player


func _await_until(condition: Callable, max_frames: int) -> void:
	for _index in max_frames:
		if condition.call():
			return
		await physics_frame


func _await_physics_frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()

	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
