extends SceneTree

# Autoload-dependent scripts are reached at runtime and kept untyped so this
# file compiles before autoloads are registered.

const TEST_SETTINGS_PATH := "user://test_settings.cfg"

var _checks: int = 0
var _failures: Array[String] = []
var _settings: Node


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_settings = root.get_node("Settings")
	_settings.settings_path = TEST_SETTINGS_PATH
	_settings.reset_to_defaults()

	_test_startup_scene()
	_test_bindings_and_swaps()
	_test_settings_round_trip()
	await _test_options_menu()
	await _test_death_screen()

	_settings.reset_to_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: options and death screen (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_startup_scene() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	_check(main_scene == "res://ui/main_menu/MainMenu.tscn", "The game must start on the main menu.")


func _test_bindings_and_swaps() -> void:
	_check(_settings.get_binding(&"jump") == KEY_SPACE, "Jump must default to Space.")
	_check(_settings.get_binding(&"left") == KEY_A, "Left must default to A.")

	var joypad_events_before := _count_joypad_events(&"jump")

	_check(_settings.set_binding(&"jump", KEY_X), "Rebinding a known action must succeed.")
	_check(_action_has_key(&"jump", KEY_X), "Rebinding must update the InputMap.")
	_check(not _action_has_key(&"jump", KEY_SPACE), "Rebinding must remove the old key.")
	_check(_count_joypad_events(&"jump") == joypad_events_before, "Rebinding must keep controller bindings.")

	_settings.set_binding(&"jump", KEY_A)
	_check(_action_has_key(&"jump", KEY_A), "Jump must take a key already in use.")
	_check(_settings.get_binding(&"left") == KEY_X, "The action that lost its key must receive the other key.")
	_check(_action_has_key(&"left", KEY_X), "Swapped keys must be applied to the InputMap.")

	_check(not _settings.set_binding(&"not_an_action", KEY_Z), "Unknown actions must be rejected.")

	_settings.reset_to_defaults()
	_check(_settings.get_binding(&"jump") == KEY_SPACE, "Reset must restore default keys.")
	_check(_action_has_key(&"left", KEY_A), "Reset must restore the InputMap.")


func _test_settings_round_trip() -> void:
	_settings.set_master_volume(0.4)
	_settings.set_fullscreen(true)
	_settings.set_binding(&"cast_attack_token", KEY_U)

	var master := AudioServer.get_bus_index(&"Master")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(master), linear_to_db(0.4)), "Volume must apply to the Master bus.")

	_check(_settings.save_settings(), "Settings must save.")

	_settings.set_master_volume(1.0)
	_settings.set_fullscreen(false)
	_settings.set_binding(&"cast_attack_token", KEY_J)
	_settings.load_settings()

	_check(is_equal_approx(_settings.master_volume, 0.4), "Loading must restore volume.")
	_check(_settings.fullscreen, "Loading must restore fullscreen.")
	_check(_action_has_key(&"cast_attack_token", KEY_U), "Loading must restore custom keys.")

	_settings.set_master_volume(0.0)
	_check(AudioServer.is_bus_mute(master), "Zero volume must mute the Master bus.")

	_settings.reset_to_defaults()
	_check(not AudioServer.is_bus_mute(master), "Reset must unmute the Master bus.")


func _test_options_menu() -> void:
	var screen = (load("res://ui/main_menu/Options.tscn") as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame

	var menu = screen.options_panel

	_check(menu.get_binding_button(&"jump") != null, "Options must list Jump.")
	_check(menu.get_binding_button(&"pause") != null, "Options must list Pause.")
	_check(menu.get_binding_button(&"jump").text == "Space", "Key buttons must show the current key.")

	menu.get_binding_button(&"jump").pressed.emit()
	_check(menu.is_capturing(), "Pressing a key button must wait for a key.")
	menu._input(_key_event(KEY_X))
	_check(not menu.is_capturing(), "A key press must end the capture.")
	_check(_settings.get_binding(&"jump") == KEY_X, "The captured key must be bound.")
	_check(menu.get_binding_button(&"jump").text == "X", "The button must show the new key.")

	menu.begin_capture(&"jump")
	menu._input(_key_event(KEY_ESCAPE))
	_check(_settings.get_binding(&"jump") == KEY_X, "Escape must cancel without rebinding.")

	menu.begin_capture(&"pause")
	menu._input(_key_event(KEY_P))
	_check(_settings.get_binding(&"pause") == KEY_P, "Pause must be rebindable.")
	menu.begin_capture(&"pause")
	menu._input(_key_event(KEY_ESCAPE))
	_check(_settings.get_binding(&"pause") == KEY_ESCAPE, "Pause must accept Escape as its key.")

	menu.volume_slider.value = 25.0
	_check(is_equal_approx(_settings.master_volume, 0.25), "The volume slider must change the volume.")
	_check(menu.volume_value_label.text == "25%", "The volume label must show the percentage.")

	menu.fullscreen_check.button_pressed = true
	_check(_settings.fullscreen, "The fullscreen toggle must change the setting.")

	menu.vsync_check.button_pressed = false
	_check(not _settings.vsync, "The V-Sync toggle must change the setting.")

	menu.reset_button.pressed.emit()
	_check(_settings.get_binding(&"jump") == KEY_SPACE, "Reset must restore keys from the menu.")
	_check(menu.get_binding_button(&"jump").text == "Space", "Reset must refresh the buttons.")
	_check(_settings.vsync, "Reset must restore V-Sync.")

	screen.queue_free()
	await process_frame
	_check(FileAccess.file_exists(TEST_SETTINGS_PATH), "Closing the options must save the settings.")


func _test_death_screen() -> void:
	var scene := load("res://entities/player/respawn/ui/DeathScreen.tscn") as PackedScene
	var probe = scene.instantiate()
	_check(is_equal_approx(probe.duration, 5.0), "The death screen must last 5 seconds by default.")
	probe.free()

	root.get_node("SaveGame").delete_save()
	change_scene_to_file("res://Main.tscn")
	await _frames(3)

	var death_screen = current_scene.get_node("DeathScreen")
	var player = current_scene.get_node("LevelRoot/Player")
	var health = player.get_node("Health")
	var pause_menu = current_scene.get_node("PauseMenuLayer/PauseMenu")

	death_screen.duration = 0.4
	death_screen.fade_out_time = 0.1
	_check(not death_screen.is_active(), "The death screen must start hidden.")

	health.take_damage(99999.0)
	await _frames(2)

	_check(death_screen.is_active(), "Dying must show the death screen.")
	_check(death_screen.overlay.visible, "Dying must cover the screen.")
	_check(death_screen.loading.visible, "Dying must show the loading indicator.")
	_check(paused, "Gameplay must pause during the death screen.")
	_check(is_equal_approx(health.current, health.maximum), "The player must respawn behind the death screen.")

	var viewport_size: Vector2 = death_screen.get_viewport().get_visible_rect().size
	var loading_rect: Rect2 = death_screen.loading.get_global_rect()
	_check(
		loading_rect.end.x > viewport_size.x * 0.75 and loading_rect.end.y > viewport_size.y * 0.75,
		"The loading indicator must sit in the bottom-right corner."
	)

	var pause := InputEventAction.new()
	pause.action = &"pause"
	pause.pressed = true
	root.push_input(pause)
	await process_frame
	_check(paused and not pause_menu.visible, "Pause must be blocked during the death screen.")

	await create_timer(0.7, true, false, true).timeout

	_check(not death_screen.is_active(), "The death screen must close after its duration.")
	_check(not death_screen.overlay.visible, "The overlay must hide after fading out.")
	_check(not paused, "Gameplay must resume after the death screen.")

	current_scene.queue_free()
	current_scene = null
	await process_frame


func _key_event(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	return event


func _action_has_key(action: StringName, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
			return true

	return false


func _count_joypad_events(action: StringName) -> int:
	var count := 0

	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			count += 1

	return count


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
