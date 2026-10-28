extends SceneTree

const COUPLE_SCENE_PATH := "res://entities/enemies/homunculus_couple/HomunculusCouple.tscn"
const RESPAWNER_SCRIPT_PATH := "res://entities/enemies/respawn/enemy_respawner.gd"
const BESTIARY_PATH := "res://entities/enemies/bestiary/bestiary.tres"
const FLOOR_Y := 24.0
const FAR_AWAY := Vector2(8000.0, 0.0)

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_composition_and_kissing()
	await _test_player_in_sight_stares_then_chases()
	await _test_chase_ignores_vision_while_on_screen()
	await _test_leaving_their_screen_ends_the_chase()
	await _test_wall_keeps_them_kissing()
	await _test_damage_skips_the_stare()
	await _test_deaths_and_drops()
	await _test_respawner_restores_couple()
	_test_bestiary_entry()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: homunculus couple (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_composition_and_kissing() -> void:
	var world := _spawn_world()
	var couple := _spawn_couple(world, Vector2.ZERO)
	var start_left := couple.left.global_position
	var start_right := couple.right.global_position

	for _index in 60:
		await physics_frame

	for animation in [&"kiss", &"stare_front", &"stare_back", &"alert", &"run", &"hit"]:
		_check(
			couple.left.sprite.sprite_frames.has_animation(animation),
			"A homunculus must have a '%s' animation." % animation
		)
	_check(
		couple.left.sprite.sprite_frames.get_frame_texture(&"run", 0).get_size() == Vector2(16.0, 16.0),
		"Placeholder frames must be 16x16."
	)
	_check(couple.get_state() == HomunculusCouple.State.KISSING, "The couple must start kissing.")
	_check(couple.heart.visible, "The heart must show while they kiss.")
	_check(couple.left.get_facing() > 0.0 and couple.right.get_facing() < 0.0, "They must face each other.")
	_check(couple.left.sprite.animation == &"kiss", "Kissing must play the kiss animation.")
	_check(
		absf(couple.left.global_position.x - start_left.x) < 1.0
		and absf(couple.right.global_position.x - start_right.x) < 1.0,
		"Kissing homunculi must stay in place."
	)
	_check(couple.left.is_on_floor() and couple.right.is_on_floor(), "Kissing homunculi must stand on the floor.")

	await _free_node(world)


func _test_player_in_sight_stares_then_chases() -> void:
	var world := _spawn_world()
	var couple := _spawn_couple(world, Vector2.ZERO)
	var player := _spawn_player(world, FAR_AWAY, true)
	var start_left := couple.left.global_position
	await _await_physics_frames(10)

	player.global_position = Vector2(-250.0, 0.0)
	await _await_physics_frames(3)

	_check(couple.get_state() == HomunculusCouple.State.STARING, "A player in sight must make them stare first.")
	_check(couple.get_target() == player, "The couple must target the player.")
	_check(couple.heart.visible, "They are still kissing while they stare.")
	_check(
		couple.left.get_state() == Homunculus.State.STARE and couple.right.get_state() == Homunculus.State.STARE,
		"Both homunculi must stare at the player."
	)
	_check(couple.left.sprite.animation == &"stare_back", "The left one must look back over its shoulder at the player.")
	_check(couple.right.sprite.animation == &"stare_front", "The right one must look ahead at the player.")
	_check(couple.left.global_position.distance_to(start_left) < 1.0, "Staring homunculi must not move.")

	await _await_physics_frames(int(ceil(couple.stare_duration * 60.0)) + 2)

	_check(couple.get_state() == HomunculusCouple.State.CHASING, "Right after the stare they must chase.")
	_check(not couple.heart.visible, "The heart must disappear when they run.")
	_check(couple.left.get_state() == Homunculus.State.CHASE, "The left homunculus must chase.")
	_check(couple.right.get_state() == Homunculus.State.CHASE, "The right homunculus must chase.")
	_check(couple.left.sprite.animation == &"run", "Chasing must play the run animation.")

	var max_speed := couple.right.horizontal_movement.max_speed
	var peak := 0.0

	for _index in 30:
		await physics_frame
		peak = maxf(peak, absf(couple.right.velocity.x))

	_check(couple.right.get_facing() < 0.0, "The right homunculus must run toward the player.")
	_check(max_speed >= 300.0, "Homunculi must be fast runners.")
	_check(is_equal_approx(peak, max_speed), "A chasing homunculus must reach its top speed.")

	await _free_node(world)


func _test_chase_ignores_vision_while_on_screen() -> void:
	var world := _spawn_world()
	var couple := _spawn_couple(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(-250.0, 0.0), true)
	await _await_physics_frames(int(ceil(couple.stare_duration * 60.0)) + 10)

	_check(couple.get_state() == HomunculusCouple.State.CHASING, "The fixture must start with a chase.")

	player.global_position = Vector2(-600.0, 0.0)
	await _await_physics_frames(3)

	_check(not couple.can_see(player), "The fixture player must be outside their vision.")
	_check(couple.is_any_member_on_screen(), "The fixture homunculi must still be on screen.")

	await _await_physics_frames(90)
	_check(couple.get_state() == HomunculusCouple.State.CHASING, "They must not stop chasing while on screen.")

	await _free_node(world)


func _test_leaving_their_screen_ends_the_chase() -> void:
	var world := _spawn_world()
	var couple := _spawn_couple(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(-250.0, 0.0), true)
	await _await_physics_frames(int(ceil(couple.stare_duration * 60.0)) + 30)

	_check(couple.get_state() == HomunculusCouple.State.CHASING, "The fixture must start with a chase.")

	player.global_position = Vector2(-6000.0, 0.0)
	await _await_physics_frames(3)

	_check(not couple.is_any_member_on_screen(), "Far from the player, the homunculi must be off screen.")
	_check(couple.get_state() == HomunculusCouple.State.CHASING, "They must not give up the instant they leave the screen.")

	await _await_physics_frames(int(ceil(couple.offscreen_grace * 60.0)) + 2)
	_check(couple.get_state() == HomunculusCouple.State.RETURNING, "Off screen for a moment, they must go home.")

	for _index in 240:
		await physics_frame
		if couple.get_state() == HomunculusCouple.State.KISSING:
			break

	_check(couple.get_state() == HomunculusCouple.State.KISSING, "Back home, they must kiss again.")
	_check(couple.heart.visible, "The heart must come back when they kiss again.")
	_check(couple.left.get_facing() > 0.0 and couple.right.get_facing() < 0.0, "They must face each other again.")
	_check(
		absf(couple.left.global_position.x + 21.0) <= couple.left.arrive_distance + 1.0
		and absf(couple.right.global_position.x - 21.0) <= couple.right.arrive_distance + 1.0,
		"Each must return to its own spot."
	)

	await _free_node(world)


func _test_wall_keeps_them_kissing() -> void:
	var world := _spawn_world()
	var couple := _spawn_couple(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(200.0, 0.0))

	_spawn_block(world, Vector2(120.0, -60.0), Vector2(20.0, 160.0))
	await _await_physics_frames(10)

	_check(couple.vision.has_target(player), "The fixture player must be inside the vision radius.")
	_check(not couple.can_see(player), "A wall must block their sight.")
	_check(couple.get_state() == HomunculusCouple.State.KISSING, "They must keep kissing when they cannot see the player.")

	await _free_node(world)


func _test_damage_skips_the_stare() -> void:
	var world := _spawn_world()
	var couple := _spawn_couple(world, Vector2.ZERO)
	var player := _spawn_player(world, FAR_AWAY)
	var attack := AttackData.new()
	await _await_physics_frames(5)

	attack.source = player
	attack.damage = 5.0
	couple.right.attack_receiver.receive_attack(attack)

	_check(couple.get_state() == HomunculusCouple.State.CHASING, "Hurting one of them must make them chase at once, without staring.")
	_check(couple.get_target() == player, "They must chase whoever hurt them.")
	_check(
		is_equal_approx(couple.right.health.current, couple.right.health.maximum - 5.0),
		"The attack must still deal its damage."
	)
	_check(couple.right.sprite.animation == &"hit", "Damage must show the hit pose.")

	await _free_node(world)


func _test_deaths_and_drops() -> void:
	var world := _spawn_world()
	var couple := _spawn_couple(world, Vector2.ZERO)
	await _await_physics_frames(5)

	couple.left.health.take_damage(couple.left.health.maximum)
	await _await_physics_frames(2)

	_check(not is_instance_valid(couple.left), "A dead homunculus must be freed.")
	_check(couple.get_state() == HomunculusCouple.State.ALONE, "The survivor must be left alone.")
	_check(not couple.heart.visible, "No heart without a partner.")
	_check(couple.right.get_state() == Homunculus.State.IDLE, "The survivor must stop kissing.")

	couple.right.health.take_damage(couple.right.health.maximum)
	await _await_physics_frames(3)

	var pickups := 0

	for child in world.get_children():
		if child is CoinPickup:
			pickups += 1

	_check(not is_instance_valid(couple), "The couple must be freed once both are dead.")
	_check(pickups == 2, "Each homunculus must drop one Stardust pickup.")

	await _free_node(world)


func _test_respawner_restores_couple() -> void:
	var world := _spawn_world()
	var respawner := Node2D.new()
	var couple := (load(COUPLE_SCENE_PATH) as PackedScene).instantiate() as HomunculusCouple

	respawner.set_script(load(RESPAWNER_SCRIPT_PATH))
	couple.vision_radius = 180.0
	couple.position = Vector2(300.0, 0.0)
	respawner.add_child(couple)
	world.add_child(respawner)
	await process_frame

	respawner.respawn_all()
	await _await_physics_frames(3)

	var respawned: HomunculusCouple = null

	for child in respawner.get_children():
		if child is HomunculusCouple and child != couple:
			respawned = child

	_check(respawned != null, "The respawner must recreate the couple.")
	if respawned != null:
		_check(is_equal_approx(respawned.vision_radius, 180.0), "Respawn must keep the vision radius.")
		_check(respawned.get_home().distance_to(Vector2(300.0, 0.0)) < 1.0, "Respawn must keep the placement.")
		_check(
			is_instance_valid(respawned.left) and is_instance_valid(respawned.right),
			"A respawned couple must have both homunculi."
		)
		_check(respawned.get_state() == HomunculusCouple.State.KISSING, "A respawned couple must be kissing.")

	await _free_node(world)


func _test_bestiary_entry() -> void:
	var bestiary := load(BESTIARY_PATH)
	var found := false

	for entry in bestiary.entries:
		if entry.id == &"homunculus_couple":
			found = true
			_check(entry.portrait != null, "The couple's guide entry must have a portrait.")

	_check(found, "The monster guide must list the Homunculus Lovers.")


func _spawn_world() -> Node2D:
	var world := Node2D.new()

	root.add_child(world)
	_spawn_block(world, Vector2(0.0, FLOOR_Y + 20.0), Vector2(20000.0, 40.0))
	return world


func _spawn_couple(parent: Node, at: Vector2) -> HomunculusCouple:
	var couple := (load(COUPLE_SCENE_PATH) as PackedScene).instantiate() as HomunculusCouple

	couple.position = at
	parent.add_child(couple)
	return couple


func _spawn_player(parent: Node, at: Vector2, with_camera: bool = false) -> CharacterBody2D:
	var player := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	var health := Health.new()
	var receiver := AttackReceiver.new()
	var receiver_shape := CollisionShape2D.new()
	var reaction := HealthDamageReaction.new()

	player.collision_layer = 4
	player.collision_mask = 0
	player.add_to_group(&"player")
	rectangle.size = Vector2(30.0, 40.0)
	shape.shape = rectangle
	player.add_child(shape)

	health.name = "Health"
	player.add_child(health)

	receiver.collision_layer = 16
	receiver.collision_mask = 0
	receiver_shape.shape = rectangle
	receiver.add_child(receiver_shape)
	reaction.health = health
	receiver.add_child(reaction)
	player.add_child(receiver)

	player.position = at
	parent.add_child(player)

	if with_camera:
		var camera := Camera2D.new()

		player.add_child(camera)
		camera.make_current()

	return player


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
