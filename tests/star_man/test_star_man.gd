extends SceneTree

const STAR_SCENE_PATH := "res://entities/enemies/star_man/StarMan.tscn"
const RESPAWNER_SCRIPT_PATH := "res://entities/enemies/respawn/enemy_respawner.gd"
const BESTIARY_PATH := "res://entities/enemies/bestiary/bestiary.tres"
const FLOOR_Y := 48.0
const FAR_AWAY := Vector2(20000.0, 0.0)

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_composition()
	await _test_waits_until_it_sees_the_player()
	await _test_screams_then_rolls_invulnerable()
	await _test_turns_back_after_overshooting()
	await _test_bounces_off_walls()
	await _test_dizzy_is_vulnerable_then_rolls_again()
	await _test_forgets_a_distant_player()
	await _test_death_drops_stardust()
	await _test_respawner_restores_star_man()
	_test_bestiary_entry()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: star man (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_composition() -> void:
	var world := _spawn_world()
	var star := _spawn_star(world, Vector2.ZERO)
	await _await_physics_frames(10)

	var frames := star.sprite.sprite_frames

	for animation in [&"idle", &"scream", &"roll", &"dizzy", &"hit"]:
		_check(frames.has_animation(animation), "The Star Man must have a '%s' animation." % animation)
	_check(frames.get_frame_texture(&"idle", 0).get_size() == Vector2(32.0, 32.0), "Star Man frames must be 32x32.")
	_check(star.collision_layer == 4 and star.collision_mask == 3, "He must be solid to the player but roll through them.")
	_check(star.is_on_floor(), "He must stand on the floor.")
	_check(star.get_state() == StarMan.State.IDLE, "He must start idle.")
	_check(star.health.maximum >= 100.0, "The Star Man must have plenty of health.")

	await _free_node(world)


func _test_waits_until_it_sees_the_player() -> void:
	var world := _spawn_world()
	var star := _spawn_star(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(300.0, 0.0))

	_spawn_block(world, Vector2(150.0, -40.0), Vector2(30.0, 120.0))
	await _await_physics_frames(10)

	_check(star.vision.has_target(player), "The fixture player must be in his vision radius.")
	_check(star.get_state() == StarMan.State.IDLE, "A wall must hide the player from him.")

	await _free_node(world)


func _test_screams_then_rolls_invulnerable() -> void:
	var world := _spawn_world()
	var star := _spawn_star(world, Vector2.ZERO)
	var player := _spawn_player(world, FAR_AWAY)
	var screams: Array[Node2D] = []

	star.screamed.connect(func(target: Node2D) -> void: screams.append(target))
	await _await_physics_frames(10)

	player.global_position = Vector2(350.0, 0.0)
	await _await_physics_frames(3)

	_check(star.get_state() == StarMan.State.SCREAM, "Seeing the player must make him scream.")
	_check(screams == [player], "He must scream once at the player.")
	_check(star.sprite.animation == &"scream", "The scream must play its animation.")
	_check(absf(star.velocity.x) < 1.0, "He must stand still while screaming.")
	_check(star.is_vulnerable(), "Standing still while screaming, he can be hurt.")

	await _await_physics_frames(int(ceil(star.scream_duration * 60.0)) + 2)

	_check(star.get_state() == StarMan.State.ROLL, "After screaming he must roll.")
	_check(star.get_roll_direction() > 0.0, "He must roll toward the player.")
	_check(not star.is_vulnerable(), "Rolling, he must not be hurt.")
	_check(star.sprite.animation == &"roll", "Rolling must play the roll animation.")
	_check(
		is_equal_approx(star.get_node("ContactImpact").contact_damage, star.roll_contact_damage),
		"Rolling must hit harder on contact."
	)

	var health_before := star.health.current
	var deflected: Array = []

	star.guard.deflected.connect(func(attack: AttackData) -> void: deflected.append(attack))
	_hit(star, player, 10.0)

	_check(is_equal_approx(star.health.current, health_before), "Attacks must bounce off while he rolls.")
	_check(deflected.size() == 1, "A blocked attack must be reported as deflected.")

	var rotation_before := star.sprite.rotation
	var peak := 0.0

	for _index in 30:
		await physics_frame
		peak = maxf(peak, absf(star.velocity.x))

	_check(is_equal_approx(peak, star.roll_speed), "He must reach his roll speed.")
	_check(absf(star.sprite.rotation - rotation_before) > PI, "The star must spin as he rolls.")

	await _free_node(world)


func _test_turns_back_after_overshooting() -> void:
	var world := _spawn_world()
	var star := _spawn_star(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(250.0, 0.0))
	var turns := 0
	var last_direction := 1.0

	star.scream_duration = 0.05
	star.roll_duration = 8.0

	for _index in 360:
		await physics_frame
		if star.get_state() == StarMan.State.ROLL:
			if star.get_roll_direction() != last_direction:
				turns += 1
				last_direction = star.get_roll_direction()

	_check(turns >= 1, "Rolling past the player, he must turn back.")
	_check(turns <= star.max_turns, "He must not turn back more than max_turns times.")
	_check(absf(star.global_position.x - player.global_position.x) < 2000.0, "He must stay around the player.")

	await _free_node(world)


func _test_bounces_off_walls() -> void:
	var world := _spawn_world()
	var star := _spawn_star(world, Vector2.ZERO)

	_spawn_player(world, Vector2(300.0, 0.0))
	_spawn_block(world, Vector2(420.0, -40.0), Vector2(40.0, 140.0))
	star.scream_duration = 0.05
	star.overshoot_distance = 5000.0

	var bounced := false

	for _index in 150:
		await physics_frame
		if star.get_state() == StarMan.State.ROLL and star.get_roll_direction() < 0.0:
			bounced = true
			break

	_check(bounced, "Hitting a wall must send him rolling the other way.")
	_check(star.global_position.x < 420.0, "He must not pass through the wall.")

	await _free_node(world)


func _test_dizzy_is_vulnerable_then_rolls_again() -> void:
	var world := _spawn_world()
	var star := _spawn_star(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(300.0, 0.0))

	star.scream_duration = 0.05
	star.roll_duration = 0.5

	await _await_until(func() -> bool: return star.get_state() == StarMan.State.DIZZY, 120)
	_check(star.get_state() == StarMan.State.DIZZY, "When the roll ends he must get dizzy.")
	_check(star.is_vulnerable(), "Dizzy, he must be open to damage.")
	_check(star.sprite.rotation == 0.0, "Dizzy, he must stand upright.")

	await _await_physics_frames(30)
	_check(absf(star.velocity.x) < 1.0, "Dizzy, he must stand still.")

	var health_before := star.health.current

	_hit(star, player, 10.0)
	_check(is_equal_approx(star.health.current, health_before - 10.0), "Hits must land while he is dizzy.")
	_check(
		is_equal_approx(star.get_node("ContactImpact").contact_damage, star.stand_contact_damage),
		"Standing, his contact damage must drop."
	)

	await _await_until(func() -> bool: return star.get_state() == StarMan.State.ROLL, 200)
	_check(star.get_state() == StarMan.State.ROLL, "With the player near, he must roll again after the daze.")

	await _free_node(world)


func _test_forgets_a_distant_player() -> void:
	var world := _spawn_world()
	var star := _spawn_star(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(300.0, 0.0))

	star.scream_duration = 0.05
	star.roll_duration = 0.3
	star.dizzy_duration = 0.3

	await _await_until(func() -> bool: return star.get_state() == StarMan.State.DIZZY, 120)
	player.global_position = FAR_AWAY
	await _await_physics_frames(25)

	_check(star.get_state() == StarMan.State.IDLE, "A player far away must be forgotten after the daze.")

	await _free_node(world)


func _test_death_drops_stardust() -> void:
	var world := _spawn_world()
	var star := _spawn_star(world, Vector2.ZERO)
	await process_frame

	star.health.take_damage(star.health.maximum)
	await process_frame
	await process_frame

	var pickups := 0

	for child in world.get_children():
		if child is CoinPickup:
			pickups += 1

	_check(not is_instance_valid(star), "A dead Star Man must be freed.")
	_check(pickups == 4, "He must drop four Stardust pickups.")

	await _free_node(world)


func _test_respawner_restores_star_man() -> void:
	var world := _spawn_world()
	var respawner := Node2D.new()
	var star := (load(STAR_SCENE_PATH) as PackedScene).instantiate() as StarMan

	respawner.set_script(load(RESPAWNER_SCRIPT_PATH))
	star.roll_speed = 500.0
	star.position = Vector2(320.0, 0.0)
	respawner.add_child(star)
	world.add_child(respawner)
	await process_frame

	respawner.respawn_all()
	await _await_physics_frames(2)

	var respawned: StarMan = null

	for child in respawner.get_children():
		if child is StarMan and child != star:
			respawned = child

	_check(respawned != null, "The respawner must recreate the Star Man.")
	if respawned != null:
		_check(is_equal_approx(respawned.roll_speed, 500.0), "Respawn must keep his roll speed.")
		_check(respawned.get_state() == StarMan.State.IDLE, "He must come back idle.")

	await _free_node(world)


func _test_bestiary_entry() -> void:
	var found := false

	for entry in load(BESTIARY_PATH).entries:
		if entry.id == &"star_man":
			found = true
			_check(entry.portrait != null, "The Star Man's guide entry must have a portrait.")

	_check(found, "The monster guide must list the Star Man.")


func _hit(star: StarMan, source: Node2D, damage: float) -> void:
	var attack := AttackData.new()

	attack.source = source
	attack.damage = damage
	(star.get_node("AttackReceiver") as AttackReceiver).receive_attack(attack)


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


func _spawn_star(parent: Node, at: Vector2) -> StarMan:
	var star := (load(STAR_SCENE_PATH) as PackedScene).instantiate() as StarMan

	star.rng_seed = 7
	star.position = at
	parent.add_child(star)
	return star


func _spawn_player(parent: Node, at: Vector2) -> CharacterBody2D:
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
	rectangle.size = Vector2(30.0, 60.0)
	shape.shape = rectangle
	player.add_child(shape)
	health.name = "Health"
	health.maximum = 1000.0
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
