extends SceneTree

const EYE_SCENE_PATH := "res://entities/enemies/flying_eye/FlyingEye.tscn"
const BOLT_SCENE_PATH := "res://entities/enemies/flying_eye/eye_bolt/EyeBolt.tscn"
const RESPAWNER_SCRIPT_PATH := "res://entities/enemies/respawn/enemy_respawner.gd"
const BESTIARY_PATH := "res://entities/enemies/bestiary/bestiary.tres"

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_scene_composition()
	await _test_patrol_stays_around_home()
	await _test_sees_player_and_fires()
	await _test_cooldown_and_rejection()
	await _test_wall_blocks_sight()
	await _test_bolt_damages_player_only()
	await _test_bolt_stops_on_world()
	await _test_bolt_expires()
	await _test_death_drops_stardust()
	await _test_respawner_restores_eye()
	_test_bestiary_entry()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: flying eye (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_scene_composition() -> void:
	var world := _spawn_world()
	var eye := _spawn_eye(world, Vector2(0.0, 0.0))
	await process_frame

	var frames := eye.sprite.sprite_frames

	_check(eye.collision_layer == 0, "The eye must not block the player or other entities.")
	_check(eye.collision_mask == 1, "The eye must only collide with the world.")
	_check(eye.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "The eye must fly without floors.")
	for animation in [&"fly", &"shoot", &"hit"]:
		_check(frames.has_animation(animation), "The eye must have a '%s' animation." % animation)
	_check(frames.get_frame_count(&"fly") == 4, "The fly animation must flap through four frames.")
	_check(
		frames.get_frame_texture(&"fly", 0).get_size() == Vector2(16.0, 16.0),
		"Eye frames must be 16x16 low-fi sprites."
	)
	_check(eye.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Pixel art must use nearest filtering.")

	await _free_node(world)


func _test_patrol_stays_around_home() -> void:
	var world := _spawn_world()
	var eye := _spawn_eye(world, Vector2(300.0, 200.0))
	await _await_physics_frames(2)

	var home := eye.get_home()
	var min_x := INF
	var max_x := -INF

	_check(home.is_equal_approx(Vector2(300.0, 200.0)), "Home must be the placement position.")

	for _index in 300:
		await physics_frame
		min_x = minf(min_x, eye.global_position.x)
		max_x = maxf(max_x, eye.global_position.x)

	_check(eye.get_state() == FlyingEye.State.PATROL, "Without a player the eye must patrol.")
	_check(max_x - min_x > eye.patrol_distance, "The patrol must sweep back and forth.")
	_check(
		min_x >= home.x - eye.patrol_distance - 8.0 and max_x <= home.x + eye.patrol_distance + 8.0,
		"The patrol must stay within patrol_distance of home."
	)
	_check(absf(eye.global_position.y - home.y) < 4.0, "The patrol must keep its height.")

	await _free_node(world)


func _test_sees_player_and_fires() -> void:
	var world := _spawn_world()
	var eye := _spawn_eye(world, Vector2(0.0, 0.0))
	var player := _spawn_player(world, Vector2(5000.0, 5000.0))
	var fired: Array[EyeBolt] = []
	var ranged: ProjectileAttackComponent = eye.ranged_attack

	ranged.projectile_parent = world
	ranged.projectile_fired.connect(func(bolt: EyeBolt) -> void: fired.append(bolt))
	await _await_physics_frames(2)

	player.global_position = Vector2(200.0, 60.0)
	await _await_physics_frames(3)

	_check(eye.get_state() == FlyingEye.State.ENGAGE, "A visible player in range must engage the eye.")
	_check(eye.get_target() == player, "The engaged eye must target the player.")
	_check(ranged.is_attacking(), "Engaging must start the wind-up.")
	_check(eye.sprite.animation == &"shoot", "The wind-up must play the shoot animation.")
	_check(fired.is_empty(), "No bolt may leave before the wind-up ends.")

	await _await_physics_frames(int(ceil(ranged.windup_duration * 60.0)) + 2)

	_check(fired.size() == 1, "The wind-up must end in exactly one bolt.")
	if fired.size() == 1 and is_instance_valid(fired[0]):
		var bolt := fired[0]
		var to_player := (player.global_position - ranged.global_position).normalized()

		_check(bolt.get_parent() == world, "The bolt must be added to the projectile parent.")
		_check(
			Vector2.RIGHT.rotated(bolt.rotation).dot(to_player) > 0.9,
			"The bolt must fly toward the player."
		)

	var start_distance := eye.global_position.distance_to(player.global_position)

	for _index in 120:
		await physics_frame

	var engage_side := signf(eye.global_position.x - player.global_position.x)

	_check(eye.global_position.y < player.global_position.y - 60.0, "The engaged eye must hover above the player.")
	_check(engage_side < 0.0, "The eye must keep to the side it came from.")
	_check(
		absf(absf(eye.global_position.x - player.global_position.x) - eye.keep_distance) < start_distance,
		"The eye must move toward its shooting distance."
	)

	player.global_position = Vector2(5000.0, 5000.0)
	await _await_physics_frames(3)
	_check(eye.get_state() == FlyingEye.State.PATROL, "Losing the player must return the eye to patrol.")
	_check(not ranged.is_attacking(), "Returning to patrol must cancel a wind-up.")

	await _free_node(world)


func _test_cooldown_and_rejection() -> void:
	var world := _spawn_world()
	var holder := Node2D.new()
	var target := Node2D.new()
	var ranged := ProjectileAttackComponent.new()
	var fired: Array[EyeBolt] = []

	ranged.source = holder
	ranged.projectile_scene = load(BOLT_SCENE_PATH)
	ranged.projectile_parent = world
	ranged.windup_duration = 0.1
	ranged.cooldown = 0.5
	ranged.projectile_fired.connect(func(bolt: EyeBolt) -> void: fired.append(bolt))
	holder.add_child(ranged)
	world.add_child(holder)
	world.add_child(target)
	target.global_position = Vector2(100.0, 0.0)
	await process_frame

	_check(not ranged.begin_attack(null), "An attack without a target must be rejected.")
	_check(not ranged.is_attacking(), "A rejected attack must not start a wind-up.")
	_check(ranged.begin_attack(target), "A ready component must accept an attack.")
	_check(not ranged.begin_attack(target), "A second attack during the wind-up must be rejected.")

	ranged._physics_process(0.11)
	_check(fired.size() == 1, "The bolt must fire when the wind-up ends.")
	_check(is_equal_approx(ranged.get_cooldown_left(), 0.5), "Firing must start the cooldown.")
	_check(not ranged.begin_attack(target), "Attacks must be rejected during the cooldown.")
	_check(is_equal_approx(ranged.get_cooldown_left(), 0.5), "A rejected attack must not restart the cooldown.")

	ranged._physics_process(0.5)
	_check(ranged.can_attack(), "The component must be ready after the cooldown.")

	ranged.begin_attack(target)
	ranged.cancel_attack()
	ranged._physics_process(0.2)
	_check(fired.size() == 1, "A cancelled wind-up must not fire.")
	_check(ranged.can_attack(), "A cancelled wind-up must not start the cooldown.")

	await _free_node(world)


func _test_wall_blocks_sight() -> void:
	var world := _spawn_world()
	var eye := _spawn_eye(world, Vector2(0.0, 0.0))
	var player := _spawn_player(world, Vector2(200.0, 0.0))

	eye.set_physics_process(false)
	_spawn_solid_block(world, Vector2(100.0, 0.0), Vector2(20.0, 400.0))
	await _await_physics_frames(3)

	_check(eye.aggro_detector.has_target(player), "The fixture player must be inside the aggro range.")
	_check(not eye.has_line_of_sight(player.global_position), "A wall must block the eye's sight.")
	_check(not eye.can_see(player), "The eye must not see a player behind a wall.")

	player.global_position = Vector2(-200.0, 0.0)
	await _await_physics_frames(3)
	_check(eye.can_see(player), "The eye must see a player with a clear line of sight.")

	await _free_node(world)


func _test_bolt_damages_player_only() -> void:
	var world := _spawn_world()
	var player := _spawn_player(world, Vector2(200.0, 0.0))
	var player_health: Health = player.get_node("Health")
	var other_enemy := _spawn_eye(world, Vector2(100.0, 0.0))
	var other_health: Health = other_enemy.health

	other_enemy.set_physics_process(false)
	await _await_physics_frames(2)

	var bolt := _launch_bolt(world, Vector2(0.0, 0.0), Vector2.RIGHT, 10.0)

	for _index in 60:
		await physics_frame

	_check(is_equal_approx(other_health.current, other_health.maximum), "Bolts must pass through other enemies.")
	_check(is_equal_approx(player_health.current, player_health.maximum - 10.0), "A bolt must damage the player once.")
	_check(not is_instance_valid(bolt), "A bolt must be freed after hitting the player.")

	await _free_node(world)


func _test_bolt_stops_on_world() -> void:
	var world := _spawn_world()
	var player := _spawn_player(world, Vector2(300.0, 0.0))
	var player_health: Health = player.get_node("Health")

	_spawn_solid_block(world, Vector2(150.0, 0.0), Vector2(20.0, 200.0))
	await _await_physics_frames(2)

	var bolt := _launch_bolt(world, Vector2(0.0, 0.0), Vector2.RIGHT, 10.0)

	for _index in 60:
		await physics_frame

	_check(not is_instance_valid(bolt), "A bolt must stop on world geometry.")
	_check(is_equal_approx(player_health.current, player_health.maximum), "A bolt stopped by a wall must not hit the player.")

	await _free_node(world)


func _test_bolt_expires() -> void:
	var world := _spawn_world()
	await process_frame

	var bolt := _launch_bolt(world, Vector2(0.0, 0.0), Vector2.UP, 10.0, 0.2)

	for _index in 20:
		await physics_frame

	_check(not is_instance_valid(bolt), "A bolt must be freed when its lifetime ends.")

	await _free_node(world)


func _test_death_drops_stardust() -> void:
	var world := _spawn_world()
	var eye := _spawn_eye(world, Vector2(0.0, 0.0))
	await process_frame

	eye.health.take_damage(eye.health.maximum)
	await process_frame
	await process_frame

	var pickups: Array[CoinPickup] = []

	for child in world.get_children():
		if child is CoinPickup:
			pickups.append(child)

	_check(not is_instance_valid(eye), "A dead eye must be freed.")
	_check(pickups.size() == 2, "A dead eye must drop two Stardust pickups.")

	await _free_node(world)


func _test_respawner_restores_eye() -> void:
	var respawner := Node2D.new()
	var eye := (load(EYE_SCENE_PATH) as PackedScene).instantiate() as FlyingEye

	respawner.set_script(load(RESPAWNER_SCRIPT_PATH))
	eye.patrol_distance = 40.0
	eye.position = Vector2(320.0, 160.0)
	respawner.add_child(eye)
	root.add_child(respawner)
	await process_frame

	respawner.respawn_all()
	await _await_physics_frames(2)

	var respawned: FlyingEye = null

	for child in respawner.get_children():
		if child is FlyingEye and child != eye:
			respawned = child

	_check(respawned != null, "The respawner must recreate the eye.")
	if respawned != null:
		_check(is_equal_approx(respawned.patrol_distance, 40.0), "Respawn must keep the placement's patrol distance.")
		_check(
			respawned.get_home().distance_to(Vector2(320.0, 160.0)) < 2.0,
			"A respawned eye must patrol around its placement, not the origin."
		)

	await _free_node(respawner)


func _test_bestiary_entry() -> void:
	var bestiary := load(BESTIARY_PATH)
	var found := false

	for entry in bestiary.entries:
		if entry.id == &"flying_eye":
			found = true
			_check(entry.portrait != null, "The Flying Eye guide entry must have a portrait.")

	_check(found, "The monster guide must list the Flying Eye.")


func _launch_bolt(
	parent: Node,
	origin: Vector2,
	direction: Vector2,
	damage: float,
	lifetime: float = 3.0
) -> EyeBolt:
	var bolt := (load(BOLT_SCENE_PATH) as PackedScene).instantiate() as EyeBolt
	var attack := AttackData.new()

	attack.attack_type = &"eye_bolt"
	attack.damage = damage
	attack.direction = direction
	parent.add_child(bolt)
	bolt.launch(origin, direction, attack, 400.0, lifetime, &"player")
	return bolt


func _spawn_world() -> Node2D:
	var world := Node2D.new()

	root.add_child(world)
	return world


func _spawn_eye(parent: Node, at: Vector2) -> FlyingEye:
	var eye := (load(EYE_SCENE_PATH) as PackedScene).instantiate() as FlyingEye

	eye.position = at
	parent.add_child(eye)
	return eye


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
	rectangle.size = Vector2(16.0, 16.0)
	shape.shape = rectangle
	player.add_child(shape)

	health.name = "Health"
	health.maximum = 100.0
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


func _spawn_solid_block(parent: Node, center: Vector2, size: Vector2) -> StaticBody2D:
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
