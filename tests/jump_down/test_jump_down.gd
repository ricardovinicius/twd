extends SceneTree

const PLAYER_SCENE := preload("res://entities/player/Player.tscn")
const MOB_SCENE := preload("res://entities/enemies/basic_skeleton/BasicSkeleton.tscn")
const LEVEL_SCENE := preload("res://levels/level_01/Level01.tscn")

const WORLD_LAYER := 1
const ONE_WAY_PLATFORM_LAYER := 2
const MAXIMUM_PHYSICS_FRAMES := 120

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await process_frame

	await _test_component_collision_mask_lifecycle()
	_test_level_uses_separate_one_way_physics_layer()
	await _test_down_and_jump_drops_through_one_way_platform()
	await _test_solid_world_collision_remains_enabled()
	await _test_mob_lands_on_one_way_platform()

	if _failures.is_empty():
		print("PASS: jump down (%d checks)" % _checks)
		quit(0)
		return

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	print("FAIL: jump down (%d failures, %d checks)" % [_failures.size(), _checks])
	quit(1)


func _test_component_collision_mask_lifecycle() -> void:
	var body := CharacterBody2D.new()
	body.collision_mask = 7
	var jump_down := JumpDownComponent.new()
	jump_down.body = body
	body.add_child(jump_down)
	root.add_child(body)
	await process_frame

	_check(not jump_down.begin(false), "Jump down must require the player to be on a floor.")
	_check(
		body.get_collision_mask_value(ONE_WAY_PLATFORM_LAYER),
		"A rejected jump down must not change the one-way platform mask."
	)

	_check(jump_down.begin(true), "A grounded player must be able to begin jump down.")
	_check(jump_down.is_active(), "Jump down must become active after it begins.")
	_check(
		not body.get_collision_mask_value(ONE_WAY_PLATFORM_LAYER),
		"Jump down must temporarily ignore the one-way platform layer."
	)
	_check(
		body.get_collision_mask_value(WORLD_LAYER),
		"Jump down must keep ordinary world collision enabled."
	)
	_check(
		body.velocity.y >= jump_down.minimum_downward_speed,
		"Jump down must apply enough downward speed to leave the platform."
	)
	jump_down.cancel()
	_check(not jump_down.is_active(), "Cancelling jump down must finish it immediately.")
	_check(
		body.get_collision_mask_value(ONE_WAY_PLATFORM_LAYER),
		"Cancelling jump down must restore one-way platform collision."
	)

	_check(jump_down.begin(true), "Jump down must be reusable after cancellation.")

	jump_down.set_physics_process(false)
	jump_down._physics_process(jump_down.ignore_duration)
	_check(not jump_down.is_active(), "Jump down must finish after its configured duration.")
	_check(
		body.get_collision_mask_value(ONE_WAY_PLATFORM_LAYER),
		"Finishing jump down must restore one-way platform collision."
	)

	await _free_node(body)


func _test_level_uses_separate_one_way_physics_layer() -> void:
	var level := LEVEL_SCENE.instantiate()
	var tile_map: TileMapLayer = level.get_node("TileMapPrincipal1")
	var tile_set := tile_map.tile_set

	_check(
		tile_set.get_physics_layers_count() == 2,
		"The principal TileSet must define solid and one-way physics layers."
	)
	_check(
		tile_set.get_physics_layer_collision_layer(0) == 1,
		"The solid TileSet physics layer must use the World collision layer."
	)
	_check(
		tile_set.get_physics_layer_collision_layer(1) == 2,
		"The one-way TileSet physics layer must use collision layer 2."
	)

	var shelf_source := tile_set.get_source(5) as TileSetAtlasSource
	var shelf_tile := shelf_source.get_tile_data(Vector2i.ZERO, 0)
	_check(
		shelf_tile.get_collision_polygons_count(0) == 0,
		"A one-way shelf tile must not also have a solid collision polygon."
	)
	_check(
		shelf_tile.get_collision_polygons_count(1) == 1,
		"A one-way shelf tile must define its polygon on the second physics layer."
	)
	_check(
		shelf_tile.is_collision_polygon_one_way(1, 0),
		"The shelf collision polygon must be configured as one-way."
	)

	level.free()


func _test_down_and_jump_drops_through_one_way_platform() -> void:
	var fixture := await _make_platform_fixture(ONE_WAY_PLATFORM_LAYER, true)
	var player: CharacterBody2D = fixture.player
	var jump_down: JumpDownComponent = player.get_node("JumpDown")
	var initial_y := player.global_position.y

	Input.action_press(&"aim_down")
	Input.action_press(&"jump")
	var started := await _wait_until(func() -> bool: return jump_down.is_active(), 5)
	Input.action_release(&"jump")
	Input.action_release(&"aim_down")

	_check(started, "Pressing Down and Jump on a one-way platform must start jump down.")
	_check(
		not player.get_collision_mask_value(ONE_WAY_PLATFORM_LAYER),
		"The player must ignore one-way platforms while beginning the drop."
	)

	var cleared_platform := await _wait_until(
		func() -> bool: return player.global_position.y > fixture.platform.global_position.y + 50.0
	)
	_check(cleared_platform, "The player must move through and below the one-way platform.")
	_check(
		player.global_position.y > initial_y,
		"Jump down must move the player downward rather than perform a normal jump."
	)

	var collision_restored := await _wait_until(
		func() -> bool:
			return player.get_collision_mask_value(ONE_WAY_PLATFORM_LAYER),
		MAXIMUM_PHYSICS_FRAMES
	)
	_check(collision_restored, "One-way platform collision must be restored after the drop.")

	await _free_node(fixture.root)


func _test_solid_world_collision_remains_enabled() -> void:
	var fixture := await _make_platform_fixture(WORLD_LAYER, false)
	var player: CharacterBody2D = fixture.player
	var jump_down: JumpDownComponent = player.get_node("JumpDown")
	var initial_y := player.global_position.y

	_check(
		jump_down.begin(player.is_on_floor()),
		"The solid-floor fixture must exercise the jump-down collision window."
	)
	await _wait_physics_frames(8)

	_check(
		player.get_collision_mask_value(WORLD_LAYER),
		"Jump down must never disable collision with ordinary world geometry."
	)
	_check(
		player.is_on_floor(),
		"A solid floor must continue supporting the player (y=%s, velocity=%s)."
			% [player.global_position.y, player.velocity]
	)
	_check(
		absf(player.global_position.y - initial_y) < 1.0,
		"Down and Jump must not pass through a solid floor (start=%s, end=%s)."
			% [initial_y, player.global_position.y]
	)

	await _free_node(fixture.root)


func _test_mob_lands_on_one_way_platform() -> void:
	var fixture_root := Node2D.new()
	fixture_root.name = "MobOneWayPlatformFixture"
	root.add_child(fixture_root)

	var platform := _make_platform(ONE_WAY_PLATFORM_LAYER, true)
	fixture_root.add_child(platform)

	var mob := MOB_SCENE.instantiate() as CharacterBody2D
	mob.position = Vector2.ZERO
	fixture_root.add_child(mob)

	_check(
		mob.get_collision_mask_value(ONE_WAY_PLATFORM_LAYER),
		"The mob must include one-way platforms in its collision mask."
	)
	var landed := await _wait_until(func() -> bool: return mob.is_on_floor())
	_check(landed, "The mob must land on a one-way platform instead of falling through it.")
	_check(
		mob.global_position.y < platform.global_position.y,
		"A mob supported by a one-way platform must remain above its surface."
	)

	await _free_node(fixture_root)


func _make_platform_fixture(collision_layer_number: int, one_way: bool) -> Dictionary:
	var fixture_root := Node2D.new()
	fixture_root.name = "JumpDownFixture"
	root.add_child(fixture_root)

	var platform := _make_platform(collision_layer_number, one_way)
	fixture_root.add_child(platform)

	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = Vector2(0.0, 0.0)
	fixture_root.add_child(player)

	var landed := await _wait_until(func() -> bool: return player.is_on_floor())
	_check(landed, "The player must land on the platform used by the test fixture.")
	return {
		"root": fixture_root,
		"platform": platform,
		"player": player,
	}


func _make_platform(collision_layer_number: int, one_way: bool) -> StaticBody2D:
	var platform := StaticBody2D.new()
	platform.name = "Platform"
	platform.position = Vector2(0.0, 100.0)
	platform.collision_layer = 1 << (collision_layer_number - 1)
	platform.collision_mask = 0

	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(240.0, 16.0)
	collision_shape.shape = rectangle
	collision_shape.one_way_collision = one_way
	platform.add_child(collision_shape)
	return platform


func _wait_until(
	predicate: Callable,
	maximum_frames: int = MAXIMUM_PHYSICS_FRAMES
) -> bool:
	for _index in maximum_frames:
		if predicate.call():
			return true
		await physics_frame

	return predicate.call()


func _wait_physics_frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _free_node(node: Node) -> void:
	if not is_instance_valid(node):
		return

	node.queue_free()
	await process_frame
	await physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
