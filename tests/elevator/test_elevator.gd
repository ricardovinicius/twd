extends SceneTree

# Elevator travel, crush safety, riding, toggle levers, level placement, and
# WASD menu navigation.

const ELEVATOR_SCENE := "res://entities/interactive/elevator/Elevator.tscn"
const LEVER_SCENE := "res://entities/interactive/lever/Lever.tscn"
const PLAYER_SCENE := "res://entities/player/Player.tscn"
const LEVEL_SCENE := "res://levels/level_01/Level01.tscn"
const WORLD_LAYER := 1
const ENTITY_LAYER := 4

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_travel_between_stops()
	await _test_crush_guard_pauses_descent()
	await _test_player_rides_platform()
	await _test_toggle_lever_flips_from_either_side()
	await _test_lever_calls_elevator()
	await _test_level_placement()
	_test_menu_navigation_keys()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: elevator (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_travel_between_stops() -> void:
	var fixture := _make_fixture()
	var switch := SwitchComponent.new()
	fixture.add_child(switch)
	var elevator := _make_elevator(fixture, Vector2(0.0, -300.0), [switch])
	await physics_frame

	_check(elevator.platform.position == Vector2.ZERO, "The elevator must start at the bottom stop.")
	_check(not elevator.is_moving(), "The elevator must start idle.")

	switch.set_active(true)
	_check(elevator.is_moving(), "A switch change must start a trip.")

	switch.set_active(false)
	_check(switch.active, "Switches must be locked while the elevator travels.")

	await _wait_until(func() -> bool: return not elevator.is_moving(), 300)
	_check(elevator.is_at_top(), "The elevator must reach the top stop.")
	_check(elevator.platform.position.is_equal_approx(Vector2(0.0, -300.0)), "The platform must stop exactly at the top.")
	_check(not switch.locked, "Switches must unlock when the elevator arrives.")

	switch.set_active(false)
	await _wait_until(func() -> bool: return not elevator.is_moving(), 300)
	_check(not elevator.is_at_top(), "The next switch change must bring it back down.")
	_check(elevator.platform.position.is_equal_approx(Vector2.ZERO), "The platform must stop exactly at the bottom.")

	await _free(fixture)


func _test_crush_guard_pauses_descent() -> void:
	var fixture := _make_fixture()
	var elevator := _make_elevator(fixture, Vector2(0.0, -300.0), [])
	elevator.start_at_top = true
	elevator._ready()
	await physics_frame

	var blocker := CharacterBody2D.new()
	blocker.collision_layer = ENTITY_LAYER
	blocker.collision_mask = 0
	blocker.add_child(_make_shape(Vector2(30.0, 60.0)))
	blocker.position = Vector2(0.0, -100.0)
	elevator.add_child(blocker)

	elevator.call_elevator()

	for i in 120:
		await physics_frame

	_check(elevator.is_moving(), "The elevator must wait while a body is under it.")
	_check(elevator.platform.position.y < blocker.position.y - 30.0, "The platform must not descend onto the body.")

	blocker.queue_free()
	await _wait_until(func() -> bool: return not elevator.is_moving(), 300)
	_check(not elevator.is_at_top(), "The elevator must finish descending once the way is clear.")

	await _free(fixture)


func _test_player_rides_platform() -> void:
	var fixture := _make_fixture()
	var elevator := _make_elevator(fixture, Vector2(0.0, -400.0), [])
	await physics_frame

	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as CharacterBody2D
	fixture.add_child(player)
	player.global_position = elevator.global_position + Vector2(0.0, -40.0)

	for i in 30:
		await physics_frame

	var start_y := player.global_position.y
	elevator.call_elevator()
	await _wait_until(func() -> bool: return not elevator.is_moving(), 400)

	for i in 10:
		await physics_frame

	var rise := start_y - player.global_position.y
	_check(absf(rise - 400.0) < 12.0, "A player on the platform must ride it up (rose %.1f)." % rise)
	_check(player.is_on_floor(), "The player must still stand on the platform at the top.")

	await _free(fixture)


func _test_toggle_lever_flips_from_either_side() -> void:
	var fixture := _make_fixture()
	var lever = (load(LEVER_SCENE) as PackedScene).instantiate()
	lever.toggle_on_any_push = true
	fixture.add_child(lever)
	await physics_frame

	var switch: SwitchComponent = lever.get_node("SwitchComponent")
	var receiver: ActionReceiver = lever.get_node("LeverHandle/ActionReceiver")

	_push(receiver, Vector2.LEFT)
	await _wait_until(func() -> bool: return switch.active, 120)
	_check(switch.active, "A toggle lever must activate when pushed toward its inactive side.")

	await _settle()
	_push(receiver, Vector2.LEFT)
	await _wait_until(func() -> bool: return not switch.active, 120)
	_check(not switch.active, "A second push from the same side must flip it back.")

	await _settle()
	_push(receiver, Vector2.UP)
	await _wait_until(func() -> bool: return switch.active, 120)
	_check(switch.active, "A toggle lever must flip even when pushed vertically.")

	await _free(fixture)

	var plain_fixture := _make_fixture()
	var plain = (load(LEVER_SCENE) as PackedScene).instantiate()
	plain_fixture.add_child(plain)
	await physics_frame

	var plain_switch: SwitchComponent = plain.get_node("SwitchComponent")
	_push(plain.get_node("LeverHandle/ActionReceiver"), Vector2.LEFT)

	for i in 60:
		await physics_frame

	_check(not plain_switch.active, "Ordinary levers must keep direction-dependent pushes.")
	await _free(plain_fixture)


func _test_lever_calls_elevator() -> void:
	var fixture := _make_fixture()
	var lever = (load(LEVER_SCENE) as PackedScene).instantiate()
	lever.toggle_on_any_push = true
	lever.position = Vector2(-260.0, 0.0)
	fixture.add_child(lever)

	var switch: SwitchComponent = lever.get_node("SwitchComponent")
	var elevator := _make_elevator(fixture, Vector2(0.0, -300.0), [switch])
	await physics_frame

	_push(lever.get_node("LeverHandle/ActionReceiver"), Vector2.RIGHT)
	await _wait_until(func() -> bool: return elevator.is_moving(), 120)
	_check(elevator.is_moving(), "Pushing an elevator lever must start the elevator.")

	await _free(fixture)


func _test_level_placement() -> void:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	await process_frame

	for key in ["A", "B", "C"]:
		var elevator := level.get_node_or_null("Elevator" + key) as Elevator
		_check(elevator != null, "Level 01 must contain Elevator%s." % key)

		if elevator == null:
			continue

		# See 018_elevators.md: ElevatorC only has its bottom lever.
		var expected_levers: int = {"A": 2, "B": 3, "C": 1}[key]

		_check(elevator.switches.size() == expected_levers, "Elevator%s must have the levers listed in the spec." % key)
		_check(key == "A" or elevator.start_at_top, "Elevator%s must start at its corridor so the corridor is not open by default." % key)

		for switch in elevator.switches:
			_check(switch != null and switch.get_parent().toggle_on_any_push, "Elevator%s levers must flip from either side." % key)

	var elevator_a := level.get_node("ElevatorA") as Elevator
	var elevator_b := level.get_node("ElevatorB") as Elevator
	_check(elevator_a.position == Vector2(2064, 5376) and elevator_a.travel == Vector2(0, -2047.5), "ElevatorA must span its shaft from y 5376 to 3312.")
	_check(elevator_b.position == Vector2(-1104, 3216) and elevator_b.travel == Vector2(0, -2191.5), "ElevatorB must span its shaft from y 3216 to 1008.")
	_check(elevator_b.start_at_top, "ElevatorB must start at the corridor so it is not open by default.")

	var left := level.get_node("ElevatorBLeverTop") as Node2D
	var right := level.get_node("ElevatorBLeverTopRight") as Node2D
	_check(left.position.x < -1296.0 and right.position.x > -912.0, "The upper corridor must have a lever on each side of the shaft.")

	var tiles := level.get_node("TileMapPrincipal1") as TileMapLayer
	var opened := true

	for x in range(-27, -19):
		for y in [21, 22]:
			if tiles.get_cell_source_id(Vector2i(x, y)) != -1:
				opened = false

	_check(opened, "The floor over shaft B must be open so the elevator reaches the corridor.")

	var elevator_c := level.get_node("ElevatorC") as Elevator
	_check(elevator_c.position == Vector2(2832, 2736) and elevator_c.travel == Vector2(0, -943.5), "ElevatorC must span its shaft from y 2736 to the corridor at 1792.5.")

	var shaft_c_open := true

	for x in range(55, 63):
		for y in range(37, 47):
			if tiles.get_cell_source_id(Vector2i(x, y)) != -1:
				shaft_c_open = false

	_check(shaft_c_open, "The floor over shaft C must be open so the elevator reaches the corridor.")
	_check(tiles.get_cell_source_id(Vector2i(54, 37)) != -1 and tiles.get_cell_source_id(Vector2i(63, 37)) != -1, "The corridor floor beside shaft C must remain.")
	_check(tiles.get_cell_source_id(Vector2i(-28, 21)) != -1 and tiles.get_cell_source_id(Vector2i(-19, 21)) != -1, "The shaft B walls beside the opening must remain.")

	level.free()


func _test_menu_navigation_keys() -> void:
	var settings := root.get_node("Settings")
	settings.reset_to_defaults()

	_check(_action_has_key(&"ui_up", KEY_W), "W must navigate menus up.")
	_check(_action_has_key(&"ui_left", KEY_A), "A must navigate menus left.")
	_check(_action_has_key(&"ui_down", KEY_S), "S must navigate menus down.")
	_check(_action_has_key(&"ui_right", KEY_D), "D must navigate menus right.")
	_check(_action_has_key(&"ui_up", KEY_UP), "Arrow keys must keep navigating menus.")

	settings.set_binding(&"aim_up", KEY_I)
	_check(_action_has_key(&"ui_up", KEY_I), "Menu navigation must follow a remapped movement key.")
	_check(not _action_has_key(&"ui_up", KEY_W), "The old movement key must stop navigating menus.")

	settings.reset_to_defaults()
	_check(_action_has_key(&"ui_up", KEY_W), "Reset must restore WASD navigation.")


func _make_fixture() -> Node2D:
	var fixture := Node2D.new()
	fixture.position = Vector2(5000.0, 5000.0)
	root.add_child(fixture)
	return fixture


func _make_elevator(parent: Node, travel: Vector2, switches: Array) -> Elevator:
	var elevator := (load(ELEVATOR_SCENE) as PackedScene).instantiate() as Elevator
	elevator.travel = travel
	elevator.speed = 900.0

	var typed: Array[SwitchComponent] = []
	for switch in switches:
		typed.append(switch)

	elevator.switches = typed
	parent.add_child(elevator)
	return elevator


func _push(receiver: Node, direction: Vector2) -> void:
	var action := ActionData.new()
	action.type = &"push"
	action.direction = direction
	action.strength = 200.0
	receiver.receive_action(action)


func _settle() -> void:
	for i in 60:
		await physics_frame


func _wait_until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return

		await physics_frame


func _make_shape(size: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	return shape


func _action_has_key(action: StringName, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey

		if key_event != null and (key_event.physical_keycode == key or key_event.keycode == key):
			return true

	return false


func _free(node: Node) -> void:
	node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
