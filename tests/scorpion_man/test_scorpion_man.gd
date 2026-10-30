extends SceneTree

const SCORPION_SCENE_PATH := "res://entities/enemies/scorpion_man/ScorpionMan.tscn"
const SKELETON_SCENE_PATH := "res://entities/enemies/basic_skeleton/BasicSkeleton.tscn"
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
	await _test_attack_depends_on_distance()
	await _test_walks_closer_then_slams()
	await _test_slam_hits_close_player()
	await _test_leap_crosses_the_room()
	await _test_damage_does_not_interrupt()
	await _test_death_drops_stardust()
	await _test_respawner_restores_scorpion()
	_test_bestiary_entry()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: scorpion man (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_composition() -> void:
	var world := _spawn_world()
	var scorpion := _spawn_scorpion(world, Vector2.ZERO)
	var skeleton := (load(SKELETON_SCENE_PATH) as PackedScene).instantiate()

	world.add_child(skeleton)
	skeleton.position = FAR_AWAY
	await _await_physics_frames(10)

	var frames := scorpion.sprite.sprite_frames

	for animation in [&"walk", &"slam", &"leap"]:
		_check(frames.has_animation(animation), "The Scorpion Man must have a '%s' animation." % animation)
	_check(frames.get_frame_count(&"slam") == 3, "The slam must have raise, strike and recover frames.")
	_check(frames.get_frame_count(&"leap") == 2, "The leap must have crouch and air frames.")
	_check(frames.get_frame_texture(&"walk", 0).get_size() == Vector2(32.0, 32.0), "Boss frames must be 32x32.")
	_check(scorpion.is_on_floor(), "He must stand on the floor.")
	_check(
		scorpion.health.maximum >= (skeleton.get_node("Health") as Health).maximum * 4.0,
		"He must be much harder to kill than a regular enemy."
	)

	await _free_node(world)


func _test_attack_depends_on_distance() -> void:
	var world := _spawn_world()
	var scorpion := _spawn_scorpion(world, Vector2.ZERO)
	await _await_physics_frames(10)

	_check(scorpion.choose_attack(Vector2(80.0, 0.0)) == ScorpionMan.Attack.SLAM, "Close up he must slam the big stinger.")
	_check(scorpion.choose_attack(Vector2(-180.0, 0.0)) == ScorpionMan.Attack.NONE, "At mid range he must walk closer.")
	_check(scorpion.choose_attack(Vector2(450.0, 0.0)) == ScorpionMan.Attack.LEAP, "Far away he must leap.")

	scorpion._leap_cooldown_left = 1.0
	_check(
		scorpion.choose_attack(Vector2(450.0, 0.0)) == ScorpionMan.Attack.NONE,
		"He must not leap again during the leap cooldown."
	)

	await _free_node(world)


func _test_walks_closer_then_slams() -> void:
	var world := _spawn_world()
	var scorpion := _spawn_scorpion(world, Vector2.ZERO)
	var player := _spawn_player(world, FAR_AWAY)
	var chosen: Array = []

	scorpion.attack_chosen.connect(func(attack: ScorpionMan.Attack) -> void: chosen.append(attack))
	await _await_physics_frames(10)

	player.global_position = Vector2(-200.0, 0.0)
	await _await_physics_frames(10)

	_check(scorpion.get_state() == ScorpionMan.State.CHASE, "At mid range he must chase.")
	_check(scorpion.velocity.x < 0.0, "He must walk toward the player.")

	await _await_until(func() -> bool: return not chosen.is_empty(), 240)
	_check(chosen == [ScorpionMan.Attack.SLAM], "Having walked close, he must slam.")

	await _await_physics_frames(10)
	_check(is_zero_approx(scorpion.velocity.x), "He must stop to attack.")

	await _free_node(world)


func _test_slam_hits_close_player() -> void:
	var world := _spawn_world()
	var scorpion := _spawn_scorpion(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(80.0, 0.0))
	var health: Health = player.get_node("Health")

	await _await_until(func() -> bool: return scorpion.get_state() == ScorpionMan.State.ATTACK, 60)

	_check(scorpion.get_current_attack() == ScorpionMan.Attack.SLAM, "A close player must get the slam.")
	_check(scorpion.facing_direction > 0.0, "He must face the player to slam.")
	_check(scorpion.sprite.animation == &"slam" and scorpion.sprite.frame == 0, "The wind-up must raise the tail.")
	_check(is_equal_approx(health.current, health.maximum), "The slam must wind up before it hits.")

	await _await_until(func() -> bool: return scorpion.sprite.frame == 1, 60)
	_check(scorpion.sprite.frame == 1, "The strike must show the stinger hitting the ground.")

	await _await_until(func() -> bool: return scorpion.get_state() != ScorpionMan.State.ATTACK, 120)
	_check(is_equal_approx(health.maximum - health.current, scorpion.slam.damage), "The slam must hit once.")

	await _free_node(world)


func _test_leap_crosses_the_room() -> void:
	var world := _spawn_world()
	var scorpion := _spawn_scorpion(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(450.0, 0.0))
	var health: Health = player.get_node("Health")
	var hits: Array[float] = []
	var peak_height := 0.0

	health.damaged.connect(func(amount: float) -> void: hits.append(amount))
	await _await_until(func() -> bool: return scorpion.get_state() == ScorpionMan.State.ATTACK, 60)

	_check(scorpion.get_current_attack() == ScorpionMan.Attack.LEAP, "A far player must get the leap.")
	_check(scorpion.facing_direction < 0.0, "He must turn his back so the butt pincers lead.")
	_check(scorpion.leap.get_direction() > 0.0, "He must leap toward the player.")

	await _await_physics_frames(int(scorpion.leap.windup_duration * 60.0) - 5)
	_check(not scorpion.leap.is_airborne(), "The crouch must give the player time to react.")

	await _await_until(func() -> bool: return scorpion.leap.is_airborne(), 30)
	_check(scorpion.leap.is_airborne(), "After the crouch he must take off.")
	_check(
		is_equal_approx(absf(scorpion.velocity.x), scorpion.leap.leap_speed),
		"He must fly across at his leap speed, slow enough to dodge."
	)
	_check(scorpion.sprite.animation == &"leap" and scorpion.sprite.frame == 1, "In the air he must show the leap pose.")

	for _index in 180:
		await physics_frame
		peak_height = maxf(peak_height, -scorpion.global_position.y)
		if not scorpion.leap.is_airborne():
			break

	_check(peak_height > 20.0, "The leap must leave the ground.")
	_check(scorpion.global_position.x > player.global_position.x, "He must fly past the player, across the room.")
	_check(scorpion.is_on_floor(), "He must land on the floor.")
	_check(hits.count(scorpion.leap.damage) == 1, "The pincers must hit the player once.")

	await _await_physics_frames(int(scorpion.leap.recovery_duration * 60.0) - 10)
	_check(scorpion.get_state() == ScorpionMan.State.ATTACK, "After landing he must stay stuck for a while.")

	await _await_until(func() -> bool: return scorpion.get_state() != ScorpionMan.State.ATTACK, 60)
	_check(
		scorpion.choose_attack(Vector2(-450.0, 0.0)) == ScorpionMan.Attack.NONE,
		"Right after landing, the leap must be cooling down."
	)

	await _free_node(world)


func _test_damage_does_not_interrupt() -> void:
	var world := _spawn_world()
	var scorpion := _spawn_scorpion(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(80.0, 0.0))
	var health: Health = player.get_node("Health")

	await _await_until(func() -> bool: return scorpion.get_state() == ScorpionMan.State.ATTACK, 60)

	var attack := AttackData.new()

	attack.source = player
	attack.damage = 10.0
	(scorpion.get_node("AttackReceiver") as AttackReceiver).receive_attack(attack)

	_check(is_equal_approx(scorpion.health.current, scorpion.health.maximum - 10.0), "He must take damage.")
	_check(scorpion.get_state() == ScorpionMan.State.ATTACK, "Damage must not interrupt his attack.")

	await _await_until(func() -> bool: return scorpion.get_state() != ScorpionMan.State.ATTACK, 120)
	_check(health.current < health.maximum, "The attack must still land after he is hit.")

	await _free_node(world)


func _test_death_drops_stardust() -> void:
	var world := _spawn_world()
	var scorpion := _spawn_scorpion(world, Vector2.ZERO)
	await process_frame

	scorpion.health.take_damage(scorpion.health.maximum)
	await process_frame
	await process_frame

	var pickups := 0

	for child in world.get_children():
		if child is CoinPickup:
			pickups += 1

	_check(not is_instance_valid(scorpion), "A dead Scorpion Man must be freed.")
	_check(pickups == 5, "He must drop five Stardust pickups.")

	await _free_node(world)


func _test_respawner_restores_scorpion() -> void:
	var world := _spawn_world()
	var respawner := Node2D.new()
	var scorpion := (load(SCORPION_SCENE_PATH) as PackedScene).instantiate() as ScorpionMan

	respawner.set_script(load(RESPAWNER_SCRIPT_PATH))
	scorpion.leap_cooldown = 4.0
	scorpion.position = Vector2(320.0, 0.0)
	respawner.add_child(scorpion)
	world.add_child(respawner)
	await process_frame

	respawner.respawn_all()
	await _await_physics_frames(2)

	var respawned: ScorpionMan = null

	for child in respawner.get_children():
		if child is ScorpionMan and child != scorpion:
			respawned = child

	_check(respawned != null, "The respawner must recreate the Scorpion Man.")
	if respawned != null:
		_check(is_equal_approx(respawned.leap_cooldown, 4.0), "Respawn must keep his leap cooldown.")
		_check(is_equal_approx(respawned.health.current, respawned.health.maximum), "He must come back at full health.")

	await _free_node(world)


func _test_bestiary_entry() -> void:
	var found := false

	for entry in load(BESTIARY_PATH).entries:
		if entry.id == &"scorpion_man":
			found = true
			_check(entry.portrait != null, "The Scorpion Man's guide entry must have a portrait.")

	_check(found, "The monster guide must list the Scorpion Man.")


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


func _spawn_scorpion(parent: Node, at: Vector2) -> ScorpionMan:
	var scorpion := (load(SCORPION_SCENE_PATH) as PackedScene).instantiate() as ScorpionMan

	scorpion.position = at
	parent.add_child(scorpion)
	return scorpion


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
