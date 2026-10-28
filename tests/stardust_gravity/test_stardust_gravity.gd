extends SceneTree

const PICKUP_SCENE := "res://currency/pickup/CoinPickup.tscn"
const SKELETON_SCENE := "res://entities/enemies/basic_skeleton/BasicSkeleton.tscn"
const WORLD_LAYER := 1
const ENTITY_LAYER := 3
const FLOOR_TOP := 400.0
const MAX_FALL_TICKS := 180

var _checks: int = 0
var _failures: Array[String] = []
var _coin_manager: Node


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_coin_manager = root.get_node("CoinManager")

	await _test_scene_composition()
	await _test_pickup_falls_and_rests_on_floor()
	await _test_pickup_ignores_non_world_layers()
	await _test_pickup_inside_floor_stays_put()
	await _test_attraction_suspends_and_resumes_fall()
	await _test_falling_pickup_is_collected_by_player()
	await _test_enemy_drop_lands_on_floor()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: stardust gravity (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_scene_composition() -> void:
	var pickup := (load(PICKUP_SCENE) as PackedScene).instantiate() as CoinPickup

	_check(pickup.fall != null, "CoinPickup.tscn must compose a PickupFallComponent.")
	if pickup.fall != null:
		_check(pickup.fall.body == pickup, "The fall component must move the pickup itself.")
		_check(pickup.fall.floor_mask == 1, "Pickups must land on world collision (layer 1) only.")
		_check(pickup.fall.gravity > 0.0, "Pickups must have some gravity.")

	pickup.free()


func _test_pickup_falls_and_rests_on_floor() -> void:
	var world := _create_world()
	_add_floor(world, WORLD_LAYER)
	var pickup := _spawn_pickup(world, Vector2(0.0, FLOOR_TOP - 150.0))
	var landed_count := [0]
	pickup.fall.landed.connect(func() -> void: landed_count[0] += 1)
	var start_y := pickup.global_position.y

	await _wait_until_resting(pickup)

	var rest_y := FLOOR_TOP - pickup.fall.rest_height
	_check(pickup.global_position.y > start_y, "A pickup in the air must fall.")
	_check(pickup.fall.is_resting(), "A falling pickup must come to rest on the floor.")
	_check(
		is_equal_approx(pickup.global_position.y, rest_y),
		"A pickup must rest on top of the floor (y=%.1f, expected %.1f)."
		% [pickup.global_position.y, rest_y]
	)

	await _physics_ticks(20)
	_check(
		is_equal_approx(pickup.global_position.y, rest_y),
		"A resting pickup must stay on the floor."
	)
	_check(landed_count[0] == 1, "A pickup must report landing exactly once.")
	_check(not pickup.collected, "Landing on the floor must not collect a pickup.")

	await _free_node(world)


func _test_pickup_ignores_non_world_layers() -> void:
	var world := _create_world()
	_add_floor(world, ENTITY_LAYER)
	var pickup := _spawn_pickup(world, Vector2(0.0, FLOOR_TOP - 40.0))

	await _physics_ticks(40)

	_check(
		pickup.global_position.y > FLOOR_TOP,
		"A pickup must fall through bodies that are not world collision."
	)

	await _free_node(world)


func _test_pickup_inside_floor_stays_put() -> void:
	var world := _create_world()
	_add_floor(world, WORLD_LAYER)
	var start := Vector2(0.0, FLOOR_TOP + 20.0)
	var pickup := _spawn_pickup(world, start)

	await _physics_ticks(10)

	_check(pickup.fall.is_resting(), "A pickup that starts inside the floor must stop.")
	_check(
		pickup.global_position.distance_to(start) < 1.0,
		"A pickup that starts inside the floor must not move or fall through."
	)

	await _free_node(world)


func _test_attraction_suspends_and_resumes_fall() -> void:
	var world := _create_world()
	_add_floor(world, WORLD_LAYER)
	var pickup := _spawn_pickup(world, Vector2(0.0, FLOOR_TOP - 200.0))
	var player := _create_player(world, Vector2(1000.0, FLOOR_TOP - 200.0))

	pickup._on_attraction_area_body_entered(player)
	_check(pickup.player == player, "The player must still attract a pickup.")
	_check(not pickup.fall.is_falling(), "Attraction must suspend the fall.")

	var attracted_from := pickup.global_position
	await _physics_ticks(10)
	_check(
		pickup.global_position.x > attracted_from.x + 1.0,
		"An attracted pickup must move toward the player."
	)
	_check(
		absf(pickup.global_position.y - attracted_from.y) < 1.0,
		"Gravity must not pull an attracted pickup away from the player."
	)

	player.free()
	await _physics_ticks(2)
	_check(pickup.player == null, "A freed player must stop the attraction.")
	_check(pickup.fall.is_falling(), "The fall must resume when the player is gone.")

	await _wait_until_resting(pickup)
	_check(
		is_equal_approx(pickup.global_position.y, FLOOR_TOP - pickup.fall.rest_height),
		"A released pickup must fall back onto the floor."
	)

	await _free_node(world)


func _test_falling_pickup_is_collected_by_player() -> void:
	var world := _create_world()
	var pickup := _spawn_pickup(world, Vector2(0.0, 0.0))
	var player := _create_player(world, Vector2(0.0, 300.0))
	var before: int = _coin_manager.coins

	await _physics_ticks(5)
	_check(pickup.fall.is_falling(), "The pickup must be falling before it is collected.")

	pickup._on_attraction_area_body_entered(player)
	pickup._on_body_entered(player)
	pickup._on_body_entered(player)
	_check(_coin_manager.coins == before + 1, "A falling pickup must be collected exactly once.")
	_check(
		not PersistentPickup.is_persistent(pickup),
		"A pickup spawned at runtime must stay non-persistent."
	)

	await create_timer(1.0).timeout
	_check(not is_instance_valid(pickup), "A collected falling pickup must free itself.")

	await _free_node(world)


func _test_enemy_drop_lands_on_floor() -> void:
	var world := _create_world()
	_add_floor(world, WORLD_LAYER)
	var skeleton := (load(SKELETON_SCENE) as PackedScene).instantiate() as Node2D
	skeleton.position = Vector2(0.0, FLOOR_TOP - 120.0)
	skeleton.set_physics_process(false)
	world.add_child(skeleton)
	await process_frame

	var health: Health = skeleton.get_node("Health")
	health.take_damage(health.maximum)
	await process_frame
	await process_frame

	var pickups: Array[CoinPickup] = []
	for child in world.get_children():
		if child is CoinPickup:
			pickups.append(child)

	_check(pickups.size() == 2, "A dead skeleton must still drop two pickups.")
	for pickup in pickups:
		await _wait_until_resting(pickup)
		_check(pickup.fall.is_resting(), "Dropped Stardust must land on the floor.")
		_check(
			is_equal_approx(pickup.global_position.y, FLOOR_TOP - pickup.fall.rest_height),
			"Dropped Stardust must rest on top of the floor."
		)
		_check(pickup.amount == 10, "Dropped Stardust must keep its amount after landing.")

	await _free_node(world)


func _create_world() -> Node2D:
	var world := Node2D.new()
	root.add_child(world)
	return world


func _add_floor(world: Node2D, layer: int) -> StaticBody2D:
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()

	rectangle.size = Vector2(2000.0, 100.0)
	shape.shape = rectangle
	floor_body.collision_layer = 0
	floor_body.set_collision_layer_value(layer, true)
	floor_body.collision_mask = 0
	floor_body.position = Vector2(0.0, FLOOR_TOP + 50.0)
	floor_body.add_child(shape)
	world.add_child(floor_body)
	return floor_body


func _spawn_pickup(world: Node2D, position: Vector2) -> CoinPickup:
	var pickup := (load(PICKUP_SCENE) as PackedScene).instantiate() as CoinPickup
	pickup.position = position
	world.add_child(pickup)
	return pickup


func _create_player(world: Node2D, position: Vector2) -> CharacterBody2D:
	var player := CharacterBody2D.new()
	player.add_to_group(&"player")
	player.position = position
	world.add_child(player)
	return player


func _wait_until_resting(pickup: CoinPickup) -> void:
	for tick in MAX_FALL_TICKS:
		if not is_instance_valid(pickup) or pickup.fall.is_resting():
			return
		await physics_frame


func _physics_ticks(count: int) -> void:
	for tick in count:
		await physics_frame


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
