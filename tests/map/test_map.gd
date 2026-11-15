extends SceneTree

const TOGGLE_ACTION := &"Select"
const SPEED_TOLERANCE := 1.0
const WALK_FRAMES := 30

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_speed_multiplier_scales_top_speed()

	change_scene_to_file("res://Main.tscn")
	await _frames(5)

	_test_main_wiring()
	await _test_toggle_opens_and_closes_without_pausing()
	await _test_player_walks_slower_while_map_is_open()
	await _test_toggle_ignored_while_paused()

	if _failures.is_empty():
		print("PASS: map (%d checks)" % _checks)
		quit(0)
		return

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	print("FAIL: map (%d failures, %d checks)" % [_failures.size(), _checks])
	quit(1)


func _test_speed_multiplier_scales_top_speed() -> void:
	var movement := HorizontalMovementComponent.new()
	movement.max_speed = 400.0
	movement.acceleration = 1000000.0

	var full_speed := movement.calculate_velocity(0.0, 1.0, 1.0)
	movement.speed_multiplier = 0.5
	var slowed_speed := movement.calculate_velocity(0.0, 1.0, 1.0)

	_check(is_equal_approx(full_speed, 400.0), "The default multiplier must keep the full top speed.")
	_check(is_equal_approx(slowed_speed, 200.0), "The multiplier must scale the top speed.")
	_check(
		is_equal_approx(movement.max_speed, 400.0),
		"The multiplier must not change max_speed, which equipment owns."
	)

	movement.free()


func _test_main_wiring() -> void:
	var map := _get_map()

	_check(map != null, "Main must contain MapLayer/MapOverlay.")

	if map == null:
		return

	_check(map.player == _get_player(), "The map must follow the level's player.")
	_check(map.horizontal_movement != null, "The map must be wired to the player's movement.")
	_check(not map.tile_layers.is_empty(), "The map must read the level's tile layers.")
	_check(not map.is_open() and not map.visible, "The map must start closed.")


func _test_toggle_opens_and_closes_without_pausing() -> void:
	var map := _get_map()

	if map == null:
		return

	await _press_toggle()

	_check(map.is_open() and map.visible, "Pressing Select (Tab) must open the map.")
	_check(not paused, "Opening the map must not pause the game.")
	_check(map.get_map_texture() != null, "Opening the map must build its texture from the tiles.")
	_check(
		is_equal_approx(map.horizontal_movement.speed_multiplier, map.move_speed_multiplier),
		"Opening the map must slow the player."
	)

	await _press_toggle()

	_check(not map.is_open() and not map.visible, "Pressing Select (Tab) again must close the map.")
	_check(
		is_equal_approx(map.horizontal_movement.speed_multiplier, 1.0),
		"Closing the map must restore the walking speed."
	)


func _test_player_walks_slower_while_map_is_open() -> void:
	var map := _get_map()
	var player := _get_player()

	if map == null or player == null:
		return

	var top_speed: float = map.horizontal_movement.max_speed
	var slowed_top_speed := top_speed * map.move_speed_multiplier

	map.open()
	Input.action_press(&"right")
	await _physics_frames(WALK_FRAMES)
	var speed_with_map: float = player.velocity.x
	Input.action_release(&"right")
	map.close()
	await _physics_frames(WALK_FRAMES)

	_check(speed_with_map > 0.0, "The player must keep moving while the map is open.")
	_check(
		speed_with_map <= slowed_top_speed + SPEED_TOLERANCE,
		"The player must not exceed the slowed speed while the map is open (%.1f > %.1f)." % [
			speed_with_map,
			slowed_top_speed,
		]
	)


func _test_toggle_ignored_while_paused() -> void:
	var map := _get_map()

	if map == null:
		return

	paused = true
	await _press_toggle()
	_check(not map.is_open(), "The map must not open while the game is paused.")
	paused = false
	await process_frame


func _press_toggle() -> void:
	var press := InputEventAction.new()
	press.action = TOGGLE_ACTION
	press.pressed = true
	root.push_input(press)
	await process_frame

	var release := InputEventAction.new()
	release.action = TOGGLE_ACTION
	release.pressed = false
	root.push_input(release)
	await process_frame


func _get_map() -> MapOverlay:
	return current_scene.get_node_or_null("MapLayer/MapOverlay") as MapOverlay


func _get_player() -> CharacterBody2D:
	return current_scene.get_node_or_null("LevelRoot/Player") as CharacterBody2D


func _frames(count: int) -> void:
	for index in count:
		await process_frame


func _physics_frames(count: int) -> void:
	for index in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
