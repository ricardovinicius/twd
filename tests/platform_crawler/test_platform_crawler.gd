extends SceneTree

const CRAWLER_SCENE_PATH := "res://entities/enemies/platform_crawler/PlatformCrawler.tscn"
const RESPAWNER_SCRIPT_PATH := "res://entities/enemies/respawn/enemy_respawner.gd"
const STEP := 0.05

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_perimeter_samples()
	await _test_perimeter_wraps_and_reverses()
	await _test_front_only_detection_and_charge()
	await _test_platform_blocks_line_of_sight()
	await _test_hit_starts_recoil_and_new_charge()
	await _test_touching_player_ahead_never_passes_through()
	await _test_death_drops_stardust()
	await _test_respawner_restores_configuration()
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	if _failures.is_empty():
		print("PASS: platform crawler (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_perimeter_samples() -> void:
	var movement := await _spawn_movement(Vector2(100.0, 40.0), 10.0, 1)
	var arc := 10.0 * PI * 0.5

	_check(
		is_equal_approx(movement.get_perimeter_length(), 280.0 + TAU * 10.0),
		"The loop length must be 2w + 2h + 2πr."
	)
	_check_sample(movement, 0.0, Vector2(-50.0, -30.0 - 10.0), 0.0, "start of the top edge")
	_check_sample(movement, 50.0, Vector2(0.0, -40.0), 0.0, "middle of the top edge")
	_check_sample(movement, 100.0 + arc + 20.0, Vector2(60.0, 0.0), 90.0, "middle of the right edge")
	_check_sample(movement, 100.0 + arc * 2.0 + 40.0 + 50.0, Vector2(0.0, 30.0), 180.0, "middle of the bottom edge")
	_check_sample(movement, 100.0 * 2.0 + arc * 3.0 + 40.0 + 20.0, Vector2(-60.0, 0.0), 270.0, "middle of the left edge")

	var platform := Rect2(Vector2(-50.0, -20.0), Vector2(100.0, 40.0))
	var length := movement.get_perimeter_length()
	var all_at_clearance := true
	for index in 64:
		var point := movement.sample(length * index / 64.0).origin
		if not is_equal_approx(_distance_to_rect(point, platform), 10.0):
			all_at_clearance = false
	_check(all_at_clearance, "Every point on the loop must stay exactly `clearance` away from the platform.")

	await _free_node(movement.get_parent())


func _test_perimeter_wraps_and_reverses() -> void:
	var movement := await _spawn_movement(Vector2(100.0, 40.0), 10.0, 1)
	var length := movement.get_perimeter_length()

	_check(
		movement.sample(length + 5.0).origin.is_equal_approx(movement.sample(5.0).origin),
		"Sampling past the loop length must wrap around."
	)

	movement.advance(5.0)
	_check(is_equal_approx(movement.distance, 5.0), "Clockwise movement must increase the distance.")
	_check(movement.get_forward().is_equal_approx(Vector2.RIGHT), "Clockwise forward on the top edge must point right.")

	movement.direction = -1
	movement.advance(2.0)
	_check(is_equal_approx(movement.distance, 3.0), "Counter-clockwise movement must decrease the distance.")
	_check(movement.get_forward().is_equal_approx(Vector2.LEFT), "Counter-clockwise forward on the top edge must point left.")
	movement.advance(8.0)
	_check(is_equal_approx(movement.distance, length - 5.0), "Counter-clockwise movement must wrap backwards.")

	await _free_node(movement.get_parent())


func _test_front_only_detection_and_charge() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var crawler := _spawn_crawler(world)
	var player := _spawn_player(world)
	await physics_frame

	var body: Node2D = crawler.get_node("Body")
	var forward: Vector2 = crawler.movement.get_forward()
	_check(forward.is_equal_approx(Vector2.RIGHT), "A clockwise crawler must start moving right along the top.")
	_check(crawler.is_in_front(body.global_position + forward * 50.0), "A point ahead must be in front.")
	_check(not crawler.is_in_front(body.global_position - forward * 50.0), "A point behind must not be in front.")
	_check(
		not crawler.is_in_front(body.global_position + Vector2.UP * 50.0),
		"A point exactly beside the travel direction must not be in front."
	)

	player.global_position = body.global_position + forward * 200.0
	await _await_physics_frames(3)
	_step(crawler, 10)
	_check(crawler.get_state() == PlatformCrawler.State.CHARGE, "A player in front must make the crawler charge.")
	_check(crawler.get_target() == player, "The charging crawler must target the player in front.")
	_check(is_equal_approx(crawler.get_speed(), crawler.charge_speed), "A charging crawler must reach charge speed.")

	player.global_position = body.global_position - crawler.movement.get_forward() * 150.0
	await _await_physics_frames(3)
	_step(crawler, 10)
	_check(crawler.get_state() == PlatformCrawler.State.PATROL, "A player behind must not be detected.")
	_check(is_equal_approx(crawler.get_speed(), crawler.patrol_speed), "The crawler must slow back to patrol speed.")

	await _free_node(world)


func _test_platform_blocks_line_of_sight() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var crawler := _spawn_crawler(world)
	# A própria plataforma do crawler, sólida na camada do mundo.
	_spawn_solid_block(world, Vector2.ZERO, crawler.platform_size)
	var player := _spawn_player(world)
	await physics_frame

	var body: Node2D = crawler.get_node("Body")
	# Crawler em cima da plataforma, andando para a direita; jogador embaixo dela.
	player.global_position = Vector2(0.0, 100.0)
	await _await_physics_frames(3)
	_check(crawler.is_in_front(player.global_position), "The fixture player must be in the crawler's front half.")
	_check(
		body.global_position.distance_to(player.global_position) < crawler.vision_radius,
		"The fixture player must be inside the vision radius."
	)
	_check(not crawler.has_line_of_sight(player.global_position), "The platform must block the line of sight.")
	_step(crawler, 4)
	_check(crawler.get_state() == PlatformCrawler.State.PATROL, "A player on the other side of the platform must not be detected.")

	player.global_position = body.global_position + crawler.movement.get_forward() * 150.0
	await _await_physics_frames(3)
	_step(crawler, 4)
	_check(crawler.get_state() == PlatformCrawler.State.CHARGE, "A player on the same side and in front must be detected.")

	await _free_node(world)


func _test_hit_starts_recoil_and_new_charge() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var crawler := _spawn_crawler(world, 150.0)
	var player := _spawn_player(world)
	await physics_frame

	var contact: ContactImpactComponent = crawler.get_node("Body/ContactImpact")
	var start_distance: float = crawler.movement.distance
	contact.contact_applied.emit(player)
	_check(crawler.get_state() == PlatformCrawler.State.RECOIL, "A contact hit must start the recoil.")

	contact.contact_applied.emit(player)
	_step(crawler, 4)
	_check(
		absf(start_distance - crawler.movement.distance - crawler.recoil_distance) < 1.0,
		"The recoil must move the crawler back by recoil_distance, once."
	)
	_check(crawler.get_state() == PlatformCrawler.State.RECOIL, "The crawler must pause after recoiling.")

	var paused_distance: float = crawler.movement.distance
	_step(crawler, 4)
	_check(is_equal_approx(crawler.movement.distance, paused_distance), "The crawler must stay still during the pause.")

	_step(crawler, 4)
	_check(crawler.get_state() != PlatformCrawler.State.RECOIL, "The crawler must resume after the pause.")
	_check(crawler.movement.distance > paused_distance, "The crawler must move forward again after the pause.")

	await _free_node(world)


func _test_touching_player_ahead_never_passes_through() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var crawler := _spawn_crawler(world, 150.0)
	var player := _spawn_player(world)
	await physics_frame

	var body: Node2D = crawler.get_node("Body")
	var contact: ContactImpactComponent = crawler.get_node("Body/ContactImpact")
	# Cooldown ativo: o contato não aplica dano nem dispara contact_applied.
	contact._cooldowns[player] = 10.0
	var hits: Array = []
	contact.contact_applied.connect(func(target: Node2D) -> void: hits.append(target))

	var start_distance: float = crawler.movement.distance
	player.global_position = body.global_position + crawler.movement.get_forward() * 20.0
	await _await_physics_frames(3)
	_check(hits.is_empty(), "The fixture contact must be on cooldown.")

	_step(crawler, 1)
	_check(crawler.get_state() == PlatformCrawler.State.RECOIL, "Touching the player ahead must start the recoil.")
	_step(crawler, 4)
	_check(crawler.movement.distance < start_distance, "The crawler must back off instead of passing through the player.")

	await _free_node(world)


func _test_death_drops_stardust() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var crawler := _spawn_crawler(world)
	await process_frame

	var health: Health = crawler.get_node("Health")
	health.take_damage(health.maximum)
	await process_frame
	await process_frame

	var pickups: Array[CoinPickup] = []
	for child in world.get_children():
		if child is CoinPickup:
			pickups.append(child)
	_check(not is_instance_valid(crawler), "A dead crawler must be freed.")
	_check(pickups.size() == 2, "A dead crawler must drop two Stardust pickups.")
	for pickup in pickups:
		_check(pickup.amount == 10, "Each crawler drop must be worth 10 Stardust.")

	await _free_node(world)


func _test_respawner_restores_configuration() -> void:
	var respawner := Node2D.new()
	respawner.set_script(load(RESPAWNER_SCRIPT_PATH))
	var crawler := (load(CRAWLER_SCENE_PATH) as PackedScene).instantiate() as PlatformCrawler
	crawler.platform_size = Vector2(100.0, 40.0)
	crawler.direction = -1
	crawler.position = Vector2(320.0, 160.0)
	crawler.set_physics_process(false)
	respawner.add_child(crawler)
	root.add_child(respawner)
	await process_frame

	respawner.respawn_all()
	await process_frame

	var respawned: PlatformCrawler = null
	for child in respawner.get_children():
		if child is PlatformCrawler and child != crawler:
			respawned = child
	_check(respawned != null, "The respawner must recreate the crawler.")
	if respawned != null:
		_check(respawned.platform_size == Vector2(100.0, 40.0), "Respawn must keep the placement's platform size.")
		_check(respawned.direction == -1, "Respawn must keep the placement's direction.")
		_check(
			respawned.movement.platform_size == Vector2(100.0, 40.0),
			"The respawned crawler must forward its platform size to the movement."
		)
		_check(respawned.global_position.is_equal_approx(Vector2(320.0, 160.0)), "Respawn must keep the placement position.")

	await _free_node(respawner)


func _spawn_movement(size: Vector2, clearance: float, direction: int) -> PerimeterMovementComponent:
	var holder := Node2D.new()
	var body := Node2D.new()
	holder.add_child(body)
	var movement := PerimeterMovementComponent.new()
	movement.body = body
	movement.platform_size = size
	movement.clearance = clearance
	movement.direction = direction
	holder.add_child(movement)
	root.add_child(holder)
	await process_frame
	return movement


func _spawn_crawler(parent: Node, start_distance: float = 0.0) -> PlatformCrawler:
	var crawler := (load(CRAWLER_SCENE_PATH) as PackedScene).instantiate() as PlatformCrawler
	crawler.start_distance = start_distance
	crawler.set_physics_process(false)
	parent.add_child(crawler)
	return crawler


func _spawn_solid_block(parent: Node, center: Vector2, size: Vector2) -> StaticBody2D:
	var block := StaticBody2D.new()
	block.collision_layer = 1
	block.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	block.add_child(shape)
	block.position = center
	parent.add_child(block)
	return block


func _spawn_player(parent: Node) -> CharacterBody2D:
	var player := CharacterBody2D.new()
	player.collision_layer = 4
	player.collision_mask = 0
	player.add_to_group(&"player")
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16.0, 16.0)
	shape.shape = rectangle
	player.add_child(shape)
	player.global_position = Vector2(5000.0, 5000.0)
	parent.add_child(player)
	return player


func _step(crawler: PlatformCrawler, count: int) -> void:
	for _index in count:
		crawler._physics_process(STEP)


func _check_sample(
	movement: PerimeterMovementComponent,
	at: float,
	expected_position: Vector2,
	expected_degrees: float,
	label: String
) -> void:
	var transform := movement.sample(at)
	_check(transform.origin.is_equal_approx(expected_position), "Wrong position at the %s." % label)
	_check(
		is_zero_approx(angle_difference(transform.get_rotation(), deg_to_rad(expected_degrees))),
		"Wrong rotation at the %s." % label
	)


func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var closest := point.clamp(rect.position, rect.end)
	return point.distance_to(closest)


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
