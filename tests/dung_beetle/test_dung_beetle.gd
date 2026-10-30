extends SceneTree

const BEETLE_SCENE_PATH := "res://entities/enemies/dung_beetle/DungBeetle.tscn"
const RESPAWNER_SCRIPT_PATH := "res://entities/enemies/respawn/enemy_respawner.gd"
const BESTIARY_PATH := "res://entities/enemies/bestiary/bestiary.tres"
const PLAYER_SPEED := 400.0
const FLOOR_Y := 24.0
const FAR_AWAY := Vector2(9000.0, 0.0)

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_composition_and_play()
	await _test_flees_rolling_the_orb()
	await _test_player_can_catch_it()
	await _test_wall_corners_it()
	await _test_calms_down_after_delay()
	await _test_death_drops_orb()
	await _test_respawner_restores_beetle()
	_test_bestiary_entry()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: dung beetle (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_composition_and_play() -> void:
	var world := _spawn_world()
	var beetle := _spawn_beetle(world, Vector2.ZERO)
	var orb_heights: Array[float] = []
	var min_x := INF
	var max_x := -INF

	for _index in 240:
		await physics_frame
		orb_heights.append(beetle.orb_visual.position.y)
		min_x = minf(min_x, beetle.global_position.x)
		max_x = maxf(max_x, beetle.global_position.x)

	var frames := beetle.sprite.sprite_frames

	_check(beetle.collision_layer == 0, "The beetle must not block the player.")
	for animation in [&"play", &"roll", &"hit"]:
		_check(frames.has_animation(animation), "The beetle must have a '%s' animation." % animation)
	_check(frames.get_frame_texture(&"roll", 0).get_size() == Vector2(16.0, 16.0), "Beetle frames must be 16x16.")
	_check(beetle.find_children("*", "ContactImpactComponent").is_empty(), "The beetle must be harmless to touch.")
	_check(beetle.horizontal_movement.max_speed < PLAYER_SPEED, "The beetle must run slower than the player.")
	_check(beetle.is_on_floor(), "The beetle must stand on the floor.")
	_check(beetle.get_state() == DungBeetle.State.PLAY, "Without a player the beetle must play.")
	_check(beetle.sprite.animation == &"play", "Playing must show the play animation.")
	_check(orb_heights.max() - orb_heights.min() > 2.0, "The beetle must toss the orb while playing.")
	_check(beetle.orb_visual.position.y < 0.0, "While playing the orb must be in its hands, above the ground.")
	_check(max_x - min_x > 8.0, "The beetle must shuffle while playing.")
	_check(
		min_x >= -beetle.play_distance - 8.0 and max_x <= beetle.play_distance + 8.0,
		"Playing must stay around its spot."
	)

	await _free_node(world)


func _test_flees_rolling_the_orb() -> void:
	var world := _spawn_world()
	var beetle := _spawn_beetle(world, Vector2.ZERO)
	var player := _spawn_player(world, FAR_AWAY)
	await _await_physics_frames(10)

	player.global_position = Vector2(-150.0, 0.0)
	await _await_physics_frames(3)

	_check(beetle.get_state() == DungBeetle.State.FLEE, "A close player must make the beetle flee.")
	_check(beetle.get_threat() == player, "The beetle must flee from the player.")

	var start_rotation := beetle.orb_visual.rotation

	await _await_physics_frames(40)

	_check(beetle.global_position.x > 100.0, "The beetle must run away from the player.")
	_check(beetle.get_facing() > 0.0, "The beetle must face away from the player.")
	_check(beetle.sprite.animation == &"roll", "Fleeing must show the roll animation.")
	_check(beetle.orb_visual.position.x > 0.0 and beetle.orb_visual.position.y > 0.0, "The orb must roll ahead on the ground.")
	_check(absf(beetle.orb_visual.rotation - start_rotation) > PI, "The orb must spin as it rolls.")
	_check(
		is_equal_approx(absf(beetle.velocity.x), beetle.horizontal_movement.max_speed),
		"The beetle must flee at its top speed."
	)

	await _free_node(world)


func _test_player_can_catch_it() -> void:
	var world := _spawn_world()
	var beetle := _spawn_beetle(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(-180.0, 0.0))
	var caught := false
	var frames := 0

	await _await_physics_frames(2)

	for _index in 360:
		await physics_frame
		frames += 1

		var offset := beetle.global_position.x - player.global_position.x

		if absf(offset) < 30.0:
			caught = true
			break

		player.global_position.x += signf(offset) * PLAYER_SPEED / 60.0

	_check(caught, "A player running at full speed must catch the beetle.")
	_check(frames > 60, "Catching the beetle must take some effort.")

	await _free_node(world)


func _test_wall_corners_it() -> void:
	var world := _spawn_world()
	var beetle := _spawn_beetle(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(-150.0, 0.0))

	_spawn_block(world, Vector2(200.0, -40.0), Vector2(40.0, 160.0))
	await _await_physics_frames(90)

	_check(beetle.get_state() == DungBeetle.State.FLEE, "The fixture beetle must be fleeing.")
	_check(beetle.is_cornered(), "A wall must corner the fleeing beetle.")
	_check(beetle.global_position.x < 200.0, "The cornered beetle must stay on its side of the wall.")

	await _free_node(world)


func _test_calms_down_after_delay() -> void:
	var world := _spawn_world()
	var beetle := _spawn_beetle(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(-150.0, 0.0))
	await _await_physics_frames(20)

	_check(beetle.get_state() == DungBeetle.State.FLEE, "The fixture must start with the beetle fleeing.")

	player.global_position = FAR_AWAY
	await _await_physics_frames(int(beetle.calm_delay * 60.0) - 10)
	_check(beetle.get_state() == DungBeetle.State.FLEE, "The beetle must keep fleeing for a moment.")

	await _await_physics_frames(30)

	var settled_x := beetle.global_position.x

	_check(beetle.get_state() == DungBeetle.State.PLAY, "The beetle must calm down after the delay.")
	_check(absf(beetle.get_home_x() - settled_x) < 40.0, "The beetle must play where it stopped.")
	_check(beetle.orb_visual.position.y < 0.0, "Calm again, the beetle must pick the orb up.")

	await _free_node(world)


func _test_death_drops_orb() -> void:
	var world := _spawn_world()
	var beetle := _spawn_beetle(world, Vector2.ZERO)
	await _await_physics_frames(5)

	var orb_position := beetle.orb_visual.global_position

	beetle.health.take_damage(beetle.health.maximum)
	await process_frame
	await process_frame

	var orbs: Array[HealthOrb] = []

	for child in world.get_children():
		if child is HealthOrb:
			orbs.append(child)

	_check(not is_instance_valid(beetle), "A dead beetle must be freed.")
	_check(orbs.size() == 1, "A dead beetle must drop its orb.")
	if orbs.size() == 1:
		_check(orbs[0].global_position.distance_to(orb_position) < 16.0, "The orb must drop where the beetle held it.")
		await _await_until(func() -> bool: return orbs[0].is_released(), 180)
		_check(orbs[0].is_released(), "The dropped orb must land and release its health.")

	await _free_node(world)


func _test_respawner_restores_beetle() -> void:
	var world := _spawn_world()
	var respawner := Node2D.new()
	var beetle := (load(BEETLE_SCENE_PATH) as PackedScene).instantiate() as DungBeetle

	respawner.set_script(load(RESPAWNER_SCRIPT_PATH))
	beetle.calm_delay = 2.0
	beetle.position = Vector2(320.0, 0.0)
	respawner.add_child(beetle)
	world.add_child(respawner)
	await process_frame

	respawner.respawn_all()
	await _await_physics_frames(2)

	var respawned: DungBeetle = null

	for child in respawner.get_children():
		if child is DungBeetle and child != beetle:
			respawned = child

	_check(respawned != null, "The respawner must recreate the beetle.")
	if respawned != null:
		_check(is_equal_approx(respawned.calm_delay, 2.0), "Respawn must keep the calm delay.")
		_check(absf(respawned.get_home_x() - 320.0) < 2.0, "Respawn must keep the placement.")
		_check(respawned.orb_visual.visible, "A respawned beetle must hold a new orb.")

	await _free_node(world)


func _test_bestiary_entry() -> void:
	var found := false

	for entry in load(BESTIARY_PATH).entries:
		if entry.id == &"dung_beetle":
			found = true
			_check(entry.portrait != null, "The beetle's guide entry must have a portrait.")

	_check(found, "The monster guide must list the beetle.")


func _spawn_world() -> Node2D:
	var world := Node2D.new()

	root.add_child(world)
	_spawn_block(world, Vector2(0.0, FLOOR_Y + 20.0), Vector2(40000.0, 40.0))
	return world


func _spawn_block(parent: Node, center: Vector2, size: Vector2) -> StaticBody2D:
	var block := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()

	block.collision_layer = 1
	block.collision_mask = 0
	rectangle.size = size
	shape.shape = rectangle
	block.add_child(shape)
	block.position = center
	parent.add_child(block)
	return block


func _spawn_beetle(parent: Node, at: Vector2) -> DungBeetle:
	var beetle := (load(BEETLE_SCENE_PATH) as PackedScene).instantiate() as DungBeetle

	beetle.position = at
	parent.add_child(beetle)
	return beetle


func _spawn_player(parent: Node, at: Vector2) -> CharacterBody2D:
	var player := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()

	player.collision_layer = 4
	player.collision_mask = 0
	player.add_to_group(&"player")
	rectangle.size = Vector2(30.0, 40.0)
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
