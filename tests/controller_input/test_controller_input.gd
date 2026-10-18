extends SceneTree

# Autoload-dependent scripts are reached at runtime and kept untyped so this
# file compiles before autoloads are registered.

const JOY_AXIS_TRIGGER := 0.9

## Controller layout the game promises. Every gameplay action must answer to
## a controller input, from any controller slot.
const BUTTON_LAYOUT: Dictionary = {
	JOY_BUTTON_A: [&"jump", &"ui_accept"],
	JOY_BUTTON_B: [&"cast_move_token", &"ui_cancel"],
	JOY_BUTTON_X: [&"cast_attack_token"],
	JOY_BUTTON_Y: [&"cast_interaction_token"],
	JOY_BUTTON_BACK: [&"Select"],
	JOY_BUTTON_START: [&"pause"],
	JOY_BUTTON_RIGHT_STICK: [&"dialogue_cancel"],
	JOY_BUTTON_LEFT_SHOULDER: [&"menu_tab_prev"],
	JOY_BUTTON_RIGHT_SHOULDER: [&"menu_tab_next"],
	JOY_BUTTON_DPAD_UP: [&"aim_up", &"ui_up"],
	JOY_BUTTON_DPAD_DOWN: [&"aim_down", &"interaction", &"ui_down"],
	JOY_BUTTON_DPAD_LEFT: [&"left", &"ui_left"],
	JOY_BUTTON_DPAD_RIGHT: [&"right", &"ui_right"],
}

const AXIS_LAYOUT: Array[Dictionary] = [
	{"axis": JOY_AXIS_LEFT_X, "value": -1.0, "actions": [&"left"]},
	{"axis": JOY_AXIS_LEFT_X, "value": 1.0, "actions": [&"right"]},
	{"axis": JOY_AXIS_LEFT_Y, "value": -1.0, "actions": [&"aim_up"]},
	{"axis": JOY_AXIS_LEFT_Y, "value": 1.0, "actions": [&"aim_down", &"interaction"]},
	{"axis": JOY_AXIS_TRIGGER_RIGHT, "value": 1.0, "actions": [&"cast_confirm_token"]},
]

const GAMEPLAY_ACTIONS: Array[StringName] = [
	&"left", &"right", &"aim_up", &"aim_down", &"jump",
	&"cast_move_token", &"cast_interaction_token", &"cast_attack_token", &"cast_confirm_token",
	&"interaction", &"dialogue_cancel", &"Select", &"pause", &"menu_tab_prev", &"menu_tab_next",
]

var _checks: int = 0
var _failures: Array[String] = []
var _settings


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_settings = root.get_node("Settings")
	_settings.reset_to_defaults()

	_test_every_action_has_a_controller_input()
	_test_button_layout()
	_test_axis_layout()
	_test_interaction_is_down()
	_test_interaction_follows_down_remap()

	root.get_node("SaveGame").delete_save()
	change_scene_to_file("res://Main.tscn")
	await _frames(5)

	await _test_interact_with_down()
	await _test_ok_button_in_dialogue()
	await _test_ok_and_back_in_menus()
	await _test_look_only_when_still()

	_settings.reset_to_defaults()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: controller input (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_every_action_has_a_controller_input() -> void:
	for action in GAMEPLAY_ACTIONS:
		var has_controller := false

		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_controller = true
				_check(event.device == -1, "%s must accept every controller, not only device %d." % [action, event.device])

		_check(has_controller, "%s must have a controller input." % action)


func _test_button_layout() -> void:
	for device in [0, 1, 3]:
		for button: int in BUTTON_LAYOUT:
			var event := InputEventJoypadButton.new()
			event.device = device
			event.button_index = button as JoyButton
			event.pressed = true
			var expected: Array = BUTTON_LAYOUT[button]

			for action in expected:
				_check(
					InputMap.event_is_action(event, action, true),
					"Controller %d button %d must trigger %s." % [device, button, action]
				)

			for action in GAMEPLAY_ACTIONS:
				if action not in expected:
					_check(
						not InputMap.event_is_action(event, action, true),
						"Controller button %d must not trigger %s." % [button, action]
					)


func _test_axis_layout() -> void:
	for entry in AXIS_LAYOUT:
		var event := InputEventJoypadMotion.new()
		event.device = 2
		event.axis = entry["axis"]
		event.axis_value = entry["value"] * JOY_AXIS_TRIGGER

		for action in entry["actions"]:
			_check(
				event.is_action_pressed(action),
				"Axis %d at %.1f must trigger %s." % [entry["axis"], event.axis_value, action]
			)

	# A light diagonal while walking must not interact.
	var walking := InputEventJoypadMotion.new()
	walking.axis = JOY_AXIS_LEFT_Y
	walking.axis_value = 0.4
	_check(walking.is_action_pressed(&"aim_down"), "A light stick tilt still aims down.")
	_check(not walking.is_action_pressed(&"interaction"), "A light stick tilt must not interact.")


func _test_interaction_is_down() -> void:
	_check(_key_triggers(KEY_S, &"interaction"), "S must interact.")
	_check(_key_triggers(KEY_S, &"aim_down"), "S must still aim down.")
	_check(not _key_triggers(KEY_E, &"interaction"), "E must no longer interact.")
	_check(_key_triggers(KEY_E, &"menu_tab_next"), "E must still switch menu tabs.")
	_check(_key_triggers(KEY_S, &"ui_down"), "S must navigate menus down.")


func _test_interaction_follows_down_remap() -> void:
	_check(not _settings.set_binding(&"interaction", KEY_F), "Interact is not remapped on its own.")
	_check(_settings.set_binding(&"aim_down", KEY_X), "Down must be remappable.")
	_check(_key_triggers(KEY_X, &"interaction"), "Interact must follow the new Down key.")
	_check(not _key_triggers(KEY_S, &"interaction"), "The old Down key must stop interacting.")

	_settings.reset_to_defaults()
	_check(_key_triggers(KEY_S, &"interaction"), "Reset must bring Interact back to S.")


func _test_interact_with_down() -> void:
	var player = current_scene.get_node("LevelRoot/Player")
	var guide = current_scene.get_node("LevelRoot/VillageGuide")
	var interactor = player.get_interactor()
	var session = interactor.dialogue_session

	player.global_position = guide.global_position
	player.velocity = Vector2.ZERO
	await _frames(20)

	_check(interactor.get_selected_target() != null, "Standing at the guide must select it.")
	_check(interactor.get_prompt().contains("S"), "The keyboard prompt must show S.")

	await _tap_button(JOY_BUTTON_DPAD_DOWN)
	_check(session.is_active(), "D-pad down must talk to the guide.")
	_check(interactor.get_prompt().is_empty(), "The prompt hides during dialogue.")

	await _tap_button(JOY_BUTTON_RIGHT_STICK)
	_check(not session.is_active(), "R3 must close the dialogue.")
	await _frames(2)
	_check(interactor.get_prompt().contains("D-pad Down"), "The controller prompt must show D-pad Down.")

	await _tap_key(KEY_S)
	_check(session.is_active(), "S must talk to the guide.")
	session.cancel()

	await _tap_stick_down()
	_check(session.is_active(), "Pushing the stick down must talk to the guide.")
	session.cancel()

	var camera = player.get_node("Camera2D")
	Input.action_press(&"aim_down")
	await _frames(40)
	_check(absf(camera._look_y) < 1.0, "Holding down to interact must not move the camera.")
	Input.action_release(&"aim_down")
	await _frames(5)


func _test_ok_button_in_dialogue() -> void:
	var player = current_scene.get_node("LevelRoot/Player")
	var guide = current_scene.get_node("LevelRoot/VillageGuide")
	var interactor = player.get_interactor()
	var session = interactor.dialogue_session
	var panel = current_scene.get_node("DialoguePanel")

	player.global_position = guide.global_position
	player.velocity = Vector2.ZERO
	await _frames(20)

	await _tap_button(JOY_BUTTON_A)
	_check(not session.is_active(), "OK must not start a conversation; Down does.")
	await _frames(40)

	await _tap_button(JOY_BUTTON_DPAD_DOWN)
	_check(session.is_active(), "D-pad down must start the conversation for the OK test.")

	if panel != null:
		_check(panel.hints.text.begins_with("A  Continue"), "The dialogue hint must show A for Continue (%s)." % panel.hints.text)

	var start_y: float = player.global_position.y
	var first_line = session.get_current_line()
	await _tap_button(JOY_BUTTON_A)
	_check(
		not session.is_active() or session.get_current_line() != first_line,
		"A must advance the dialogue."
	)
	_check(player.is_on_floor() and absf(player.global_position.y - start_y) < 2.0, "A in dialogue must not jump.")

	for i in 20:
		if not session.is_active():
			break

		await _tap_button(JOY_BUTTON_A)

	_check(not session.is_active(), "Pressing A through the lines must finish the conversation.")
	await _frames(10)
	_check(player.is_on_floor() and absf(player.global_position.y - start_y) < 2.0, "Closing dialogue with A must not jump.")

	await _tap_key(KEY_S)
	_check(session.is_active(), "S must start the conversation for the Enter test.")
	var line = session.get_current_line()
	await _tap_key(KEY_ENTER)
	_check(not session.is_active() or session.get_current_line() != line, "Enter must advance the dialogue.")
	session.cancel()

	await _tap_button(JOY_BUTTON_A)
	await _frames(2)
	_check(player.velocity.y < 0.0, "A outside dialogue must still jump.")
	await _frames(60)


func _test_ok_and_back_in_menus() -> void:
	var menu = current_scene.get_node("PauseMenuLayer/PauseMenu")

	await _tap_button(JOY_BUTTON_START)
	_check(paused and menu.visible, "Start must open the pause menu.")

	menu.general_items_button.grab_focus()
	await _tap_button(JOY_BUTTON_A)
	_check(menu.overlay.visible, "A must press the focused menu button.")

	await _tap_button(JOY_BUTTON_B)
	_check(not menu.overlay.visible and paused, "B must close a section first.")

	menu.select_tab(3)
	await _frames(2)
	_check(menu.resume_button.has_focus(), "The Quit tab must focus Continue.")
	await _tap_button(JOY_BUTTON_B)
	await _frames(30)
	_check(not paused and not menu.visible, "B must resume the game from the pause menu.")

	await _tap_button(JOY_BUTTON_START)
	menu.select_tab(3)
	await _frames(2)
	await _tap_button(JOY_BUTTON_A)
	await _frames(30)
	_check(not paused and not menu.visible, "A on Continue must resume the game.")
	await _frames(60)


func _test_look_only_when_still() -> void:
	var player = current_scene.get_node("LevelRoot/Player")
	var guide = current_scene.get_node("LevelRoot/VillageGuide")
	var camera = player.get_node("Camera2D")

	player.global_position = guide.global_position + Vector2(-450, 0)
	player.velocity = Vector2.ZERO
	await _frames(40)
	_check(player.is_on_floor(), "The look test spot must be on the floor.")
	_check(player.get_interactor().get_selected_target() == null, "The look test spot must be away from the guide.")

	Input.action_press(&"aim_up")
	await _frames(40)
	_check(camera._look_y < -60.0, "Standing still and holding up must look up (%.1f)." % camera._look_y)
	Input.action_release(&"aim_up")
	await _frames(60)
	_check(absf(camera._look_y) < 5.0, "Releasing up must recenter the camera.")

	Input.action_press(&"aim_down")
	await _frames(40)
	_check(camera._look_y > 60.0, "Standing still and holding down must look down (%.1f)." % camera._look_y)
	Input.action_release(&"aim_down")
	await _frames(60)

	Input.action_press(&"right")
	Input.action_press(&"aim_up")
	await _frames(14)
	_check(absf(player.velocity.x) > 1.0 and player.is_on_floor(), "The player must be walking on the floor in this check.")
	_check(absf(camera._look_y) < 5.0, "Walking while holding up must not look up (%.1f)." % camera._look_y)
	Input.action_release(&"right")
	await _frames(20)
	_check(camera._look_y < -40.0, "Stopping while still holding up must start looking up.")
	Input.action_release(&"aim_up")

	Input.action_press(&"aim_up")
	player.velocity = Vector2(0, -400)
	await _frames(1)
	_check(not player.is_on_floor(), "The player must be airborne in this check.")
	await _frames(15)
	_check(camera._look_y > -40.0, "Holding up in the air must not keep looking up.")
	Input.action_release(&"aim_up")
	await _frames(60)


func _key_triggers(key: Key, action: StringName) -> bool:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	return InputMap.event_is_action(event, action, true)


func _tap_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(3)

	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(3)


func _tap_key(key: Key) -> void:
	# Real key presses carry both codes; ui_accept matches the logical one.
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(3)

	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(3)


func _tap_stick_down() -> void:
	for value in [0.3, 0.8, 1.0, 1.0]:
		var event := InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_LEFT_Y
		event.axis_value = value
		Input.parse_input_event(event)
		await _frames(1)

	var release := InputEventJoypadMotion.new()
	release.axis = JOY_AXIS_LEFT_Y
	release.axis_value = 0.0
	Input.parse_input_event(release)
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
