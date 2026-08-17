extends SceneTree

const LEVER_SCENE := preload("res://entities/interactive/lever/Lever.tscn")
const DOOR_SCENE := preload("res://entities/interactive/door/Door.tscn")
const LEVEL_SCENE := preload("res://levels/level_01/Level01.tscn")
const PLAYER_SCENE := preload("res://entities/player/Player.tscn")
const PUSH_SPELL_SCENE := preload("res://spells/action/push/PushSpell.tscn")
const BOTTLE_LINE_SCENE := preload("res://entities/items/BottleLine.tscn")
const BOTTLE_TRIANGLE_SCENE := preload("res://entities/items/BottleTriangle.tscn")

const MAXIMUM_FRAMES := 120
const PUSH_STRENGTH := 200.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await process_frame

	_test_switch_component()
	_test_player_and_spell_force_configuration()
	await _test_initial_active_lever_pose()
	await _test_one_real_push_spell_activates_lever()
	await _test_lever_push_reaction()
	await _test_rigid_body_collision_activates_lever()
	await _test_character_collision_does_not_activate_lever()
	await _test_character_collision_moves_bottles()
	await _test_door_cycle()
	await _test_obstruction_safety()
	await _test_one_switch_controls_multiple_doors()
	_test_level_wiring()

	if _failures.is_empty():
		print("PASS: doors and levers (%d checks)" % _checks)
		quit(0)
		return

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	print("FAIL: doors and levers (%d failures, %d checks)" % [_failures.size(), _checks])
	quit(1)


func _test_switch_component() -> void:
	var switch := SwitchComponent.new()
	var emissions: Array[bool] = []
	switch.state_changed.connect(func(active: bool) -> void: emissions.append(active))

	switch.set_active(false)
	_check(emissions.is_empty(), "Setting the current switch state must be idempotent.")
	switch.toggle()
	_check(switch.active, "A normal switch must activate on its first toggle.")
	switch.toggle()
	_check(not switch.active, "A normal switch must deactivate on its second toggle.")
	_check(emissions == [true, false], "A switch must emit exactly once per real state change.")

	var one_shot_switch := SwitchComponent.new()
	one_shot_switch.one_shot = true
	one_shot_switch.toggle()
	one_shot_switch.toggle()
	_check(one_shot_switch.active, "A one-shot switch must ignore toggles after activation.")

	switch.free()
	one_shot_switch.free()


func _test_player_and_spell_force_configuration() -> void:
	var player := PLAYER_SCENE.instantiate()
	var player_push: CharacterRigidBodyPushComponent = player.get_node("RigidBodyPush")
	var push_spell := PUSH_SPELL_SCENE.instantiate() as PushSpell
	_check(
		is_equal_approx(player_push.impulse_factor, 0.1),
		"The player must use a bottle-capable rigid-body contact impulse factor."
	)
	_check(
		is_equal_approx(player_push.maximum_impulse, 1.0),
		"The player must cap contact pushes below the lever activation force."
	)
	_check(
		is_equal_approx(push_spell.push_strength, PUSH_STRENGTH),
		"The Push spell must expose the stronger lever-capable force."
	)
	player.free()
	push_spell.free()


func _test_initial_active_lever_pose() -> void:
	var lever := LEVER_SCENE.instantiate() as Lever
	lever.position = Vector2(-300, -300)
	var switch: SwitchComponent = lever.get_node("SwitchComponent")
	switch.active = true
	root.add_child(lever)
	await physics_frame

	var handle: RigidBody2D = lever.get_node("LeverHandle")
	var grip: Polygon2D = lever.get_node("LeverHandle/Grip")
	_check(rad_to_deg(handle.rotation) > 30.0, "An active lever must start at its active stop.")
	_check(grip.color == lever.active_grip_color, "Initial lever feedback must match active state.")

	await _free_node(lever)


func _test_one_real_push_spell_activates_lever() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)

	var lever := LEVER_SCENE.instantiate() as Lever
	lever.position = Vector2(-300, -500)
	fixture.add_child(lever)

	var caster := Node2D.new()
	caster.position = Vector2(-355, -529)
	caster.scale = Vector2(3, 3)
	fixture.add_child(caster)
	var push_spell := PUSH_SPELL_SCENE.instantiate() as PushSpell
	caster.add_child(push_spell)
	await physics_frame

	var context := SpellContext.new()
	context.caster = caster
	context.effect_parent = caster
	context.origin = caster.global_position
	context.direction = Vector2.RIGHT
	push_spell.execute(context)

	var switch: SwitchComponent = lever.get_node("SwitchComponent")
	var handle: RigidBody2D = lever.get_node("LeverHandle")
	var maximum_angle := rad_to_deg(handle.rotation)
	for _index in MAXIMUM_FRAMES:
		if switch.active:
			break
		await physics_frame
		maximum_angle = maxf(maximum_angle, rad_to_deg(handle.rotation))
	_check(
		switch.active,
		"One cast from the real PushSpell scene must activate an inactive lever "
		+ "(maximum angle=%s, final angle=%s, velocity=%s)." % [
			maximum_angle,
			rad_to_deg(handle.rotation),
			handle.angular_velocity,
		]
	)

	if is_instance_valid(push_spell):
		push_spell.cancel()
	await _free_node(fixture)


func _test_lever_push_reaction() -> void:
	var lever := LEVER_SCENE.instantiate() as Lever
	lever.position = Vector2(-300, 0)
	root.add_child(lever)
	await physics_frame

	var switch: SwitchComponent = lever.get_node("SwitchComponent")
	var receiver: ActionReceiver = lever.get_node("LeverHandle/ActionReceiver")
	var handle: RigidBody2D = lever.get_node("LeverHandle")
	var unrelated_action := ActionData.new()
	unrelated_action.type = &"attack"
	receiver.receive_action(unrelated_action)
	_check(not switch.active, "A lever must ignore actions other than push.")

	var weak_push := _make_push_action(Vector2.RIGHT, 1.0)
	receiver.receive_action(weak_push)
	_check(not switch.active, "Receiving Push must not change switch state directly.")
	await _wait_physics_frames(45)
	_check(not switch.active, "A weak Push must not activate the physical lever.")
	_check(
		rad_to_deg(handle.rotation) < -30.0,
		"A weakly disturbed lever must settle back toward its inactive stop."
	)

	var strong_push := _make_push_action(Vector2.RIGHT, PUSH_STRENGTH)
	receiver.receive_action(strong_push)
	var activated := await _wait_until(func() -> bool: return switch.active)
	_check(
		activated,
		"One Push action must move the handle across the active threshold "
		+ "(angle=%s, velocity=%s)." % [rad_to_deg(handle.rotation), handle.angular_velocity]
	)
	_check(handle.rotation > 0.0, "An active physical lever must move toward its active stop.")

	var reverse_push := _make_push_action(Vector2.LEFT, PUSH_STRENGTH)
	receiver.receive_action(reverse_push)
	_check(
		await _wait_until(func() -> bool: return not switch.active),
		"An opposite Push must move a normal lever across the inactive threshold."
	)
	_check(handle.rotation < 0.0, "An inactive physical lever must move toward its inactive stop.")

	switch.one_shot = true
	receiver.receive_action(_make_push_action(Vector2.RIGHT, PUSH_STRENGTH))
	var one_shot_activated := await _wait_until(func() -> bool: return switch.active)
	_check(
		one_shot_activated,
		"A one-shot physical lever must activate after crossing its active threshold "
		+ "(angle=%s, velocity=%s)." % [rad_to_deg(handle.rotation), handle.angular_velocity]
	)

	receiver.receive_action(_make_push_action(Vector2.LEFT, 300.0))
	await _wait_physics_frames(30)
	_check(switch.active, "An active one-shot lever must ignore physical deactivation.")
	_check(
		rad_to_deg(handle.rotation) > 30.0,
		"An active one-shot lever must remain latched at its active stop."
	)

	await _free_node(lever)


func _test_rigid_body_collision_activates_lever() -> void:
	var lever := LEVER_SCENE.instantiate() as Lever
	lever.position = Vector2(-300, 300)
	root.add_child(lever)
	await physics_frame

	var switch: SwitchComponent = lever.get_node("SwitchComponent")
	var handle: RigidBody2D = lever.get_node("LeverHandle")
	_check(handle.is_in_group(&"character_pushable"), "The handle must use the pushable group.")
	_check(handle.collision_layer == 4, "The physical handle must use the Entities layer.")
	_check(handle.collision_mask == 5, "The handle must collide with World and Entities.")

	var weak_body := _make_moving_rigid_body()
	weak_body.mass = 0.1
	weak_body.position = Vector2(-390, 250)
	weak_body.linear_velocity = Vector2(100, 0)
	root.add_child(weak_body)
	await _wait_physics_frames(90)
	_check(not switch.active, "A low-momentum rigid-body collision must not activate the lever.")
	await _free_node(weak_body)
	await physics_frame

	var moving_body := _make_moving_rigid_body()
	moving_body.position = Vector2(-390, 250)
	moving_body.linear_velocity = Vector2(1000, 0)
	root.add_child(moving_body)

	_check(
		await _wait_until(func() -> bool: return switch.active, 180),
		"A moving rigid body with enough momentum must physically activate the lever."
	)

	await _free_node(moving_body)
	await _free_node(lever)


func _test_character_collision_does_not_activate_lever() -> void:
	var lever := LEVER_SCENE.instantiate() as Lever
	lever.position = Vector2(-300, 600)
	root.add_child(lever)
	await physics_frame

	var switch: SwitchComponent = lever.get_node("SwitchComponent")
	var character := _make_character_pusher()
	character.position = Vector2(-365, 568)
	root.add_child(character)
	await physics_frame

	var push_component: CharacterRigidBodyPushComponent = character.get_node("RigidBodyPush")
	var intended_velocity := Vector2(400, 0)
	for _index in 120:
		character.velocity = intended_velocity
		character.move_and_slide()
		push_component.push_slide_collisions(intended_velocity)
		await physics_frame

	var handle: RigidBody2D = lever.get_node("LeverHandle")
	_check(
		not switch.active,
		"Player body collision must not activate the lever "
		+ "(character=%s, handle=%s, angle=%s)."
		% [character.position, handle.global_position, rad_to_deg(handle.rotation)]
	)
	_check(
		rad_to_deg(handle.rotation) < -30.0,
		"The lever must settle at its inactive stop after player contact."
	)

	await _free_node(character)
	await _free_node(lever)


func _test_character_collision_moves_bottles() -> void:
	for bottle_scene: PackedScene in [BOTTLE_LINE_SCENE, BOTTLE_TRIANGLE_SCENE]:
		var fixture := Node2D.new()
		root.add_child(fixture)

		var floor_body := StaticBody2D.new()
		floor_body.position = Vector2(0, 34)
		var floor_shape := CollisionShape2D.new()
		var floor_rectangle := RectangleShape2D.new()
		floor_rectangle.size = Vector2(400, 20)
		floor_shape.shape = floor_rectangle
		floor_body.add_child(floor_shape)
		fixture.add_child(floor_body)

		var bottle := bottle_scene.instantiate() as RigidBody2D
		fixture.add_child(bottle)
		var initial_x := bottle.position.x

		var player := PLAYER_SCENE.instantiate() as CharacterBody2D
		player.position = Vector2(-75, -25)
		fixture.add_child(player)
		player.set_physics_process(false)
		await _wait_physics_frames(10)

		var push_component: CharacterRigidBodyPushComponent = player.get_node("RigidBodyPush")
		var movement: HorizontalMovementComponent = player.get_node("HorizontalMovement")
		for _index in 120:
			player.velocity.x = movement.calculate_velocity(player.velocity.x, 1.0, 1.0 / 60.0)
			var intended_velocity := player.velocity
			player.move_and_slide()
			push_component.push_slide_collisions(intended_velocity)
			await physics_frame

		_check(
			bottle.position.x >= initial_x + 20.0,
			"Player collision must move %s (distance=%s)." % [
				bottle.name,
				bottle.position.x - initial_x,
			]
		)
		await _free_node(fixture)


func _test_door_cycle() -> void:
	var switch := SwitchComponent.new()
	root.add_child(switch)
	var door := _make_door(switch)
	root.add_child(door)
	await process_frame

	_check(door.state == DoorController.State.CLOSED, "An inactive switch must start its door closed.")
	_check(not door.door_collision.disabled, "A closed door must start with collision enabled.")

	switch.set_active(true)
	_check(
		await _wait_until(func() -> bool: return door.door_collision.disabled),
		"Opening a door must disable collision at its configured release frame."
	)
	var opened := await _wait_until(func() -> bool: return door.state == DoorController.State.OPEN)
	_check(
		opened,
		"An active switch must finish opening its door."
	)

	switch.set_active(false)
	_check(
		await _wait_until(func() -> bool: return door.state == DoorController.State.CLOSED),
		"An inactive switch must finish closing an unobstructed door."
	)
	await physics_frame
	_check(not door.door_collision.disabled, "A safely closed door must restore collision.")

	await _free_node(door)
	await _free_node(switch)


func _test_obstruction_safety() -> void:
	var switch := SwitchComponent.new()
	switch.active = true
	root.add_child(switch)
	var door := _make_door(switch)
	root.add_child(door)
	await process_frame

	var body := _make_entity_body()
	body.position = Vector2(0, -49)
	root.add_child(body)
	await _wait_physics_frames(2)

	switch.set_active(false)
	_check(
		door.state == DoorController.State.WAITING_TO_CLOSE,
		"A close request must wait while an entity occupies the doorway."
	)
	_check(door.door_collision.disabled, "A waiting door must not restore collision on an entity.")

	body.position = Vector2(100, -49)
	_check(
		await _wait_until(func() -> bool: return door.state == DoorController.State.CLOSING),
		"A waiting door must retry closing after the doorway clears."
	)

	body.position = Vector2(0, -49)
	_check(
		await _wait_until(func() -> bool: return door.state == DoorController.State.OPENING),
		"A door must reverse toward open when an entity enters during closing."
	)
	_check(door.door_collision.disabled, "A reversing door must keep collision disabled.")

	body.position = Vector2(100, -49)
	_check(
		await _wait_until(func() -> bool: return door.state == DoorController.State.CLOSED),
		"A reversed door must close once its doorway is clear again."
	)
	await physics_frame
	_check(not door.door_collision.disabled, "Collision must return only after the safe close finishes.")

	await _free_node(body)
	await _free_node(door)
	await _free_node(switch)


func _test_one_switch_controls_multiple_doors() -> void:
	var switch := SwitchComponent.new()
	root.add_child(switch)
	var first_door := _make_door(switch)
	var second_door := _make_door(switch)
	second_door.position.x = 100.0
	root.add_child(first_door)
	root.add_child(second_door)
	await process_frame

	switch.set_active(true)
	var both_doors_are_open := func() -> bool:
		return (
			first_door.state == DoorController.State.OPEN
			and second_door.state == DoorController.State.OPEN
		)
	_check(
		await _wait_until(both_doors_are_open),
		"One switch must be able to open multiple referenced doors."
	)

	await _free_node(second_door)
	await _free_node(first_door)
	await _free_node(switch)


func _test_level_wiring() -> void:
	var level := LEVEL_SCENE.instantiate()
	var lever: Lever = level.get_node("Lever")
	var door: DoorController = level.get_node("Door")
	var switch: SwitchComponent = lever.get_node("SwitchComponent")
	_check(door.switch == switch, "Level01's example door must reference its placed lever switch.")
	level.free()


func _make_door(switch: SwitchComponent) -> DoorController:
	var door := DOOR_SCENE.instantiate() as DoorController
	door.switch = switch
	return door


func _make_push_action(direction: Vector2, strength: float) -> ActionData:
	var action := ActionData.new()
	action.type = &"push"
	action.direction = direction
	action.strength = strength
	return action


func _make_entity_body() -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 40)
	collision_shape.shape = rectangle
	body.add_child(collision_shape)
	return body


func _make_moving_rigid_body() -> RigidBody2D:
	var body := RigidBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 4
	body.mass = 0.5
	body.gravity_scale = 0.0
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	var collision_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	collision_shape.shape = circle
	body.add_child(collision_shape)
	return body


func _make_character_pusher() -> CharacterBody2D:
	var character := CharacterBody2D.new()
	character.collision_layer = 4
	character.collision_mask = 4
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 30)
	collision_shape.shape = rectangle
	character.add_child(collision_shape)
	var push_component := CharacterRigidBodyPushComponent.new()
	push_component.name = "RigidBodyPush"
	push_component.character = character
	push_component.impulse_factor = 0.1
	push_component.maximum_impulse = 1.0
	character.add_child(push_component)
	return character


func _wait_until(predicate: Callable, maximum_frames: int = MAXIMUM_FRAMES) -> bool:
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


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
