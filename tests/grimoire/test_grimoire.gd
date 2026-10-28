extends SceneTree

const GRIMOIRE_SCENE := "res://entities/companions/grimoire/Grimoire.tscn"
const LEVEL_SCENE := "res://levels/level_01/Level01.tscn"
const TICK := 1.0 / 60.0
const PLAYER_SCALE := 3.0

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_scene_composition()
	await _test_starts_beside_target()
	await _test_follows_smoothly()
	await _test_passes_through_walls()
	await _test_switches_side_with_target_direction()
	await _test_snaps_after_teleport()
	await _test_removed_target_is_safe()
	await _test_level_composition()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: grimoire (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_scene_composition() -> void:
	var grimoire := (load(GRIMOIRE_SCENE) as PackedScene).instantiate() as Node2D
	var sprite := grimoire.get_node("Sprite") as Node2D
	var follow := grimoire.get_node("CompanionFollow") as CompanionFollowComponent
	var hover := grimoire.get_node("HoverBob") as HoverBobComponent

	_check(follow != null and follow.body == grimoire, "The follow component must move the grimoire root.")
	_check(hover != null and hover.visual == sprite, "The hover component must animate the sprite only.")
	_check(
		sprite.scale.is_equal_approx(Vector2(PLAYER_SCALE, PLAYER_SCALE)),
		"The grimoire sprite must use the player's scale."
	)

	var bounds := _sprite_bounds(sprite)
	_check(
		bounds.size.x <= 32.0 and bounds.size.y <= 32.0,
		"The placeholder art must fit a 32x32 sprite (got %s)." % bounds.size
	)
	_check(
		bounds.size.x >= 24.0 and bounds.size.y >= 24.0,
		"The placeholder art must be close to the player's 32x32 size (got %s)." % bounds.size
	)
	_check(
		_collision_objects(grimoire).is_empty(),
		"The grimoire must have no collision, so it passes through blocks."
	)

	grimoire.free()


func _test_starts_beside_target() -> void:
	var fixture := _create_fixture(Vector2(500.0, 300.0))
	var grimoire: Node2D = fixture.grimoire
	var follow: CompanionFollowComponent = fixture.follow
	await process_frame

	_check(
		grimoire.global_position.is_equal_approx(follow.get_destination()),
		"The grimoire must start at its spot beside the target."
	)

	await _free_node(fixture.world)


func _test_follows_smoothly() -> void:
	var fixture := _create_fixture(Vector2.ZERO)
	var grimoire: Node2D = fixture.grimoire
	var follow: CompanionFollowComponent = fixture.follow
	var target: Node2D = fixture.target
	await process_frame

	target.global_position += Vector2(0.0, -400.0)
	var previous_distance := grimoire.global_position.distance_to(follow.get_destination())
	var previous_position := grimoire.global_position
	var always_closer := true
	var largest_step := 0.0

	for tick in 90:
		await physics_frame
		var distance := grimoire.global_position.distance_to(follow.get_destination())
		always_closer = always_closer and distance <= previous_distance + 0.01
		largest_step = maxf(largest_step, grimoire.global_position.distance_to(previous_position))
		previous_distance = distance
		previous_position = grimoire.global_position

	_check(always_closer, "The grimoire must keep closing in on its spot.")
	_check(previous_distance < 20.0, "The grimoire must reach its spot near the target (%.1f px away)." % previous_distance)
	_check(
		largest_step <= follow.max_speed * TICK * 1.5 + 0.01,
		"The grimoire must glide, never jump, toward a nearby target (largest step %.1f)." % largest_step
	)
	_check(
		largest_step < 400.0 * 0.5,
		"The grimoire must not cover the distance in a single tick."
	)

	await _free_node(fixture.world)


func _test_passes_through_walls() -> void:
	var fixture := _create_fixture(Vector2.ZERO)
	var grimoire: Node2D = fixture.grimoire
	var follow: CompanionFollowComponent = fixture.follow
	var target: Node2D = fixture.target
	await process_frame

	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(64.0, 2000.0)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = Vector2(300.0, 0.0)
	fixture.world.add_child(wall)

	target.global_position = Vector2(700.0, 0.0)
	for tick in 120:
		await physics_frame

	_check(
		grimoire.global_position.distance_to(follow.get_destination()) < 20.0,
		"The grimoire must pass through a wall to reach the target."
	)

	await _free_node(fixture.world)


func _test_switches_side_with_target_direction() -> void:
	var fixture := _create_fixture(Vector2.ZERO)
	var follow: CompanionFollowComponent = fixture.follow
	var target: Node2D = fixture.target
	await process_frame

	var right_side_offset := follow.get_destination().x - target.global_position.x
	_check(right_side_offset < 0.0, "Facing right, the grimoire must float behind (to the left of) the target.")

	for tick in 5:
		target.global_position.x -= 10.0
		await physics_frame
	await physics_frame

	var left_side_offset := follow.get_destination().x - target.global_position.x
	_check(left_side_offset > 0.0, "Moving left, the grimoire must switch behind (to the right of) the target.")
	_check(
		is_equal_approx(left_side_offset, -right_side_offset),
		"Switching sides must mirror the horizontal offset."
	)

	await _free_node(fixture.world)


func _test_snaps_after_teleport() -> void:
	var fixture := _create_fixture(Vector2.ZERO)
	var grimoire: Node2D = fixture.grimoire
	var follow: CompanionFollowComponent = fixture.follow
	var target: Node2D = fixture.target
	var snaps := [0]
	follow.snapped_to_target.connect(func() -> void: snaps[0] += 1)
	await process_frame

	target.global_position = Vector2(follow.snap_distance * 3.0, 0.0)
	await physics_frame
	await physics_frame

	_check(snaps[0] >= 1, "A far teleport must snap the grimoire.")
	_check(
		grimoire.global_position.distance_to(follow.get_destination()) < 1.0,
		"After a far teleport the grimoire must be beside the target."
	)

	await _free_node(fixture.world)


func _test_removed_target_is_safe() -> void:
	var fixture := _create_fixture(Vector2.ZERO)
	var grimoire: Node2D = fixture.grimoire
	await process_frame

	var resting_position := grimoire.global_position
	fixture.target.free()
	for tick in 5:
		await physics_frame

	_check(
		grimoire.global_position.is_equal_approx(resting_position),
		"Without a target the grimoire must stay where it is."
	)

	await _free_node(fixture.world)


func _test_level_composition() -> void:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate()
	var grimoire := level.get_node_or_null("Grimoire") as Node2D
	var player := level.get_node_or_null("Player") as Node2D

	_check(grimoire != null, "Level 01 must compose the Grimoire.")
	if grimoire != null:
		var follow := grimoire.get_node("CompanionFollow") as CompanionFollowComponent
		_check(follow.target == player, "The level's Grimoire must follow the level's Player.")
		_check(
			grimoire.get_index() < player.get_index(),
			"The Grimoire must come before the Player so it is drawn behind her."
		)

	level.free()


func _create_fixture(target_position: Vector2) -> Dictionary:
	var world := Node2D.new()
	var target := Node2D.new()
	var grimoire := (load(GRIMOIRE_SCENE) as PackedScene).instantiate() as Node2D
	var follow := grimoire.get_node("CompanionFollow") as CompanionFollowComponent

	target.position = target_position
	world.add_child(target)
	follow.target = target
	world.add_child(grimoire)
	root.add_child(world)

	return {
		"world": world,
		"target": target,
		"grimoire": grimoire,
		"follow": follow,
	}


func _sprite_bounds(sprite: Node2D) -> Rect2:
	var bounds := Rect2()
	var has_points := false

	for child in sprite.get_children():
		var polygon := child as Polygon2D
		if polygon == null:
			continue
		for point in polygon.polygon:
			if not has_points:
				bounds = Rect2(point, Vector2.ZERO)
				has_points = true
			else:
				bounds = bounds.expand(point)

	return bounds


func _collision_objects(node: Node) -> Array[Node]:
	var found: Array[Node] = []

	if node is CollisionObject2D:
		found.append(node)

	for child in node.get_children():
		found.append_array(_collision_objects(child))

	return found


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
