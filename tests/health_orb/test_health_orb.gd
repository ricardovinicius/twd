extends SceneTree

const ORB_SCENE_PATH := "res://health/orb/HealthOrb.tscn"
const PLAYER_SCENE_PATH := "res://entities/player/Player.tscn"
const FLOOR_Y := 200.0

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_health_heal()
	await _test_player_heal_capability()
	await _test_orb_falls_then_releases()
	await _test_orb_heals_player_once_released()
	await _test_full_health_leaves_the_orb()
	await _test_player_waiting_below_collects_on_landing()
	await _test_drop_on_death()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: health orb (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_health_heal() -> void:
	var health := Health.new()
	var healed: Array[float] = []
	var changes: Array[float] = []

	health.maximum = 100.0
	root.add_child(health)
	health.healed.connect(func(amount: float) -> void: healed.append(amount))
	health.changed.connect(func(current: float, _maximum: float) -> void: changes.append(current))

	_check(is_zero_approx(health.heal(10.0)), "Full health must not heal.")
	_check(healed.is_empty() and changes.is_empty(), "A rejected heal must not emit signals.")

	health.take_damage(40.0)
	changes.clear()
	_check(is_equal_approx(health.heal(25.0), 25.0), "Heal must restore the requested amount.")
	_check(is_equal_approx(health.current, 85.0), "Heal must raise current health.")
	_check(healed == [25.0] and changes == [85.0], "Heal must emit healed and changed.")
	_check(is_equal_approx(health.heal(50.0), 15.0), "Heal must stop at maximum and report what it restored.")
	_check(health.is_full(), "Health must be full after overhealing.")
	_check(is_zero_approx(health.heal(-5.0)), "Negative heals must be ignored.")

	health.take_damage(100.0)
	_check(is_zero_approx(health.heal(50.0)), "Depleted health must not be healed.")
	_check(health.is_depleted(), "A rejected heal must not revive.")

	health.free()


func _test_player_heal_capability() -> void:
	var world := _spawn_world()
	var player := _spawn_player(world, Vector2(0.0, 0.0))
	await process_frame

	var health: Health = player.get_node("Health")

	_check(not player.can_heal(), "A player at full health cannot heal.")
	health.take_damage(30.0)
	_check(player.can_heal(), "A hurt player can heal.")
	_check(is_equal_approx(player.heal(20.0), 20.0), "Player heal must restore health.")
	_check(is_equal_approx(health.current, health.maximum - 10.0), "Player heal must use the player's Health.")

	await _free_node(world)


func _test_orb_falls_then_releases() -> void:
	var world := _spawn_world()
	var orb := _spawn_orb(world, Vector2(0.0, 0.0))
	await _await_physics_frames(2)

	_check(not orb.is_released(), "A dropped orb must not release health while falling.")
	_check(orb.sprite.animation == &"falling", "A falling orb must show the falling animation.")

	await _await_until(func() -> bool: return orb.is_released(), 120)

	_check(orb.is_released(), "The orb must release its health once it lands.")
	_check(absf(orb.global_position.y - (FLOOR_Y - 12.0)) < 1.0, "The orb must rest on the floor.")
	_check(orb.sprite.animation == &"released", "A released orb must glow.")

	await _free_node(world)


func _test_orb_heals_player_once_released() -> void:
	var world := _spawn_world()
	var player := _spawn_player(world, Vector2(400.0, 0.0))
	var health: Health = player.get_node("Health")
	var orb := _spawn_orb(world, Vector2(0.0, 0.0))
	var collected: Array[float] = []

	orb.collected.connect(func(_target: Node2D, restored: float) -> void: collected.append(restored))
	await process_frame
	health.take_damage(50.0)

	# Falls past the player without being collected.
	player.global_position = Vector2(0.0, 80.0)
	await _await_physics_frames(4)
	_check(is_equal_approx(health.current, health.maximum - 50.0), "A falling orb must not heal.")

	player.global_position = Vector2(400.0, 0.0)
	await _await_until(func() -> bool: return orb.is_released(), 120)

	player.global_position = Vector2(0.0, FLOOR_Y - 40.0)
	await _await_physics_frames(4)

	_check(is_equal_approx(health.current, health.maximum - 25.0), "Touching a released orb must heal 25.")
	_check(collected == [25.0], "Collecting must report the restored health once.")
	_check(not is_instance_valid(orb), "A collected orb must be freed.")

	await _free_node(world)


func _test_full_health_leaves_the_orb() -> void:
	var world := _spawn_world()
	var player := _spawn_player(world, Vector2(400.0, 0.0))
	var orb := _spawn_orb(world, Vector2(0.0, 0.0))
	await _await_until(func() -> bool: return orb.is_released(), 120)

	player.global_position = Vector2(0.0, FLOOR_Y - 40.0)
	await _await_physics_frames(4)

	_check(is_instance_valid(orb) and not orb.is_collected(), "A player at full health must leave the orb.")

	player.get_node("Health").take_damage(10.0)
	await _await_physics_frames(3)
	_check(not is_instance_valid(orb), "The orb must be collected once the player can heal.")

	await _free_node(world)


func _test_player_waiting_below_collects_on_landing() -> void:
	var world := _spawn_world()
	var player := _spawn_player(world, Vector2(0.0, FLOOR_Y - 40.0))
	var health: Health = player.get_node("Health")
	await process_frame

	health.take_damage(30.0)

	var orb := _spawn_orb(world, Vector2(0.0, 0.0))

	await _await_physics_frames(90)

	_check(not is_instance_valid(orb), "A player already standing there must collect the orb when it lands.")
	_check(is_equal_approx(health.current, health.maximum - 5.0), "Landing on the player must heal once.")

	await _free_node(world)


func _test_drop_on_death() -> void:
	var world := _spawn_world()
	var carrier := Node2D.new()
	var hand := Node2D.new()
	var held := Sprite2D.new()
	var health := Health.new()
	var drop := HealthOrbDropOnDeath.new()
	var dropped: Array[HealthOrb] = []

	carrier.position = Vector2(50.0, 20.0)
	hand.position = Vector2(4.0, 6.0)
	hand.add_child(held)
	carrier.add_child(hand)
	health.maximum = 10.0
	carrier.add_child(health)
	drop.health = health
	drop.hand = hand
	drop.held_orb = held
	drop.orb_scene = load(ORB_SCENE_PATH)
	drop.drop_parent = world
	drop.heal_amount = 40.0
	drop.dropped.connect(func(orb: HealthOrb) -> void: dropped.append(orb))
	carrier.add_child(drop)
	world.add_child(carrier)
	await process_frame

	health.take_damage(10.0)
	await process_frame

	_check(dropped.size() == 1, "Death must drop exactly one orb.")
	_check(not held.visible, "The held orb must disappear when it is dropped.")
	if dropped.size() == 1:
		var orb := dropped[0]

		_check(orb.get_parent() == world, "The orb must be added to the drop parent.")
		_check(orb.global_position.distance_to(Vector2(54.0, 26.0)) < 1.0, "The orb must start at the hand.")
		_check(is_equal_approx(orb.heal_amount, 40.0), "The drop must apply its heal override.")
		_check(not orb.is_released(), "A dropped orb must start falling.")

	await _free_node(world)


func _spawn_world() -> Node2D:
	var world := Node2D.new()
	var block := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()

	block.collision_layer = 1
	block.collision_mask = 0
	rectangle.size = Vector2(4000.0, 40.0)
	shape.shape = rectangle
	block.add_child(shape)
	block.position = Vector2(0.0, FLOOR_Y + 20.0)
	world.add_child(block)
	root.add_child(world)
	return world


func _spawn_orb(parent: Node, at: Vector2) -> HealthOrb:
	var orb := (load(ORB_SCENE_PATH) as PackedScene).instantiate() as HealthOrb

	orb.position = at
	parent.add_child(orb)
	return orb


func _spawn_player(parent: Node, at: Vector2) -> CharacterBody2D:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as CharacterBody2D

	player.set_physics_process(false)
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
