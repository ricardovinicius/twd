extends Node

## Owns player-facing options (volume, fullscreen, keyboard bindings), applies
## them to the engine, and persists them to disk. UI reads and changes options
## only through this API.

signal changed

const SETTINGS_PATH := "user://settings.cfg"

const SECTION_AUDIO := "audio"
const SECTION_VIDEO := "video"
const SECTION_INPUT := "input"

const MASTER_BUS := &"Master"
const DEFAULT_VOLUME := 1.0
const DEFAULT_FULLSCREEN := false
const DEFAULT_VSYNC := true

## Actions the player can rebind, in display order, with their labels.
const REMAPPABLE_ACTIONS: Array[Dictionary] = [
	{"action": &"left", "label": "Move left"},
	{"action": &"right", "label": "Move right"},
	{"action": &"aim_up", "label": "Aim up"},
	{"action": &"aim_down", "label": "Down: Aim / Interact / Drop"},
	{"action": &"jump", "label": "Jump"},
	{"action": &"cast_move_token", "label": "Spell: Move token"},
	{"action": &"cast_interaction_token", "label": "Spell: Interaction token"},
	{"action": &"cast_attack_token", "label": "Spell: Attack token"},
	{"action": &"cast_confirm_token", "label": "Spell: Confirm"},
	{"action": &"dialogue_cancel", "label": "Cancel / Back"},
	{"action": &"Select", "label": "Select"},
	{"action": &"pause", "label": "Pause / Menu"},
]

## Actions that always share another action's keyboard key. Interacting is
## done by pressing down, so it follows whatever key Aim down uses.
const LINKED_ACTIONS: Dictionary[StringName, StringName] = {
	&"interaction": &"aim_down",
}

## Menu navigation follows the movement keys (WASD by default), in addition
## to the arrow keys and controller inputs Godot already maps.
const MENU_NAVIGATION: Dictionary[StringName, StringName] = {
	&"ui_up": &"aim_up",
	&"ui_down": &"aim_down",
	&"ui_left": &"left",
	&"ui_right": &"right",
}

## Fixed keys that switch pause-menu tabs, and the remappable actions that are
## also read inside menus. Those actions may not take a tab key, or one press
## would do two things (e.g. Pause on E would close the menu instead of
## switching tabs).
const MENU_TAB_ACTIONS: Array[StringName] = [&"menu_tab_prev", &"menu_tab_next"]
const MENU_ACTIVE_ACTIONS: Array[StringName] = [&"pause", &"left", &"right", &"aim_up", &"aim_down"]

## Overridable so tests can write to an isolated file.
var settings_path: String = SETTINGS_PATH

var master_volume: float = DEFAULT_VOLUME
var fullscreen: bool = DEFAULT_FULLSCREEN
var vsync: bool = DEFAULT_VSYNC

var _bindings: Dictionary[StringName, Key] = {}
var _default_bindings: Dictionary[StringName, Key] = {}
var _menu_navigation_events: Dictionary[StringName, InputEventKey] = {}


func _ready() -> void:
	for entry in REMAPPABLE_ACTIONS:
		var action: StringName = entry["action"]
		_default_bindings[action] = _read_key(action)

	load_settings()


func get_binding(action: StringName) -> Key:
	return _bindings.get(action, KEY_NONE)


func get_key_label(action: StringName) -> String:
	var key := get_binding(action)

	if key == KEY_NONE:
		return "-"

	return OS.get_keycode_string(key)


func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	_apply_volume()
	changed.emit()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_fullscreen()
	changed.emit()


func set_vsync(enabled: bool) -> void:
	vsync = enabled
	_apply_vsync(true)
	changed.emit()


## Display label for a spell token, using its current keyboard binding.
func get_token_key_label(token: StringName) -> String:
	var action := StringName("cast_%s_token" % token)

	if get_binding(action) == KEY_NONE:
		return String(token)

	return get_key_label(action)


## Display label for a spell sequence, e.g. "L + K".
func format_sequence(sequence: Array[StringName]) -> String:
	var keys := PackedStringArray()

	for token in sequence:
		keys.append(get_token_key_label(token))

	return " + ".join(keys)


## Binds a physical key to an action. If another remappable action already
## uses that key, the two actions swap keys so no input is left ambiguous.
## Returns false for unknown actions or KEY_NONE.
## Explains why `key` cannot be bound to `action` (including the key the
## swapped action would receive), or returns "" when the binding is allowed.
func get_binding_conflict(action: StringName, key: Key) -> String:
	if not _default_bindings.has(action) or key == KEY_NONE:
		return "Invalid action or key."

	var previous := get_binding(action)

	if _is_menu_key_clash(action, key):
		return "%s switches menu tabs and cannot be used for this action." % OS.get_keycode_string(key)

	for other: StringName in _bindings:
		if other != action and _bindings[other] == key and _is_menu_key_clash(other, previous):
			return "This swap would put %s on an action used in menus." % OS.get_keycode_string(previous)

	return ""


func set_binding(action: StringName, key: Key) -> bool:
	if not get_binding_conflict(action, key).is_empty():
		return false

	var previous := get_binding(action)

	if previous == key:
		return true

	for other: StringName in _bindings:
		if other != action and _bindings[other] == key:
			_bindings[other] = previous
			_write_key(other, previous)

	_bindings[action] = key
	_write_key(action, key)
	_sync_menu_navigation()
	changed.emit()

	return true


func reset_to_defaults() -> void:
	var vsync_changed := vsync != DEFAULT_VSYNC

	master_volume = DEFAULT_VOLUME
	fullscreen = DEFAULT_FULLSCREEN
	vsync = DEFAULT_VSYNC

	for action: StringName in _default_bindings:
		_bindings[action] = _default_bindings[action]
		_write_key(action, _default_bindings[action])

	_apply_volume()
	_apply_fullscreen()
	_apply_vsync(vsync_changed)
	_sync_menu_navigation()
	changed.emit()


func save_settings() -> bool:
	var file := ConfigFile.new()

	file.set_value(SECTION_AUDIO, "master_volume", master_volume)
	file.set_value(SECTION_VIDEO, "fullscreen", fullscreen)
	file.set_value(SECTION_VIDEO, "vsync", vsync)

	for action: StringName in _bindings:
		file.set_value(SECTION_INPUT, String(action), int(_bindings[action]))

	var error := file.save(settings_path)

	if error != OK:
		push_error("Settings: Could not write '%s' (error %d)." % [settings_path, error])
		return false

	return true


func load_settings() -> void:
	var file := ConfigFile.new()
	var has_file := FileAccess.file_exists(settings_path) and file.load(settings_path) == OK

	master_volume = clampf(file.get_value(SECTION_AUDIO, "master_volume", DEFAULT_VOLUME), 0.0, 1.0)
	fullscreen = file.get_value(SECTION_VIDEO, "fullscreen", DEFAULT_FULLSCREEN)
	vsync = file.get_value(SECTION_VIDEO, "vsync", DEFAULT_VSYNC)

	for action: StringName in _default_bindings:
		var key: Key = _default_bindings[action]

		if has_file:
			key = file.get_value(SECTION_INPUT, String(action), int(key)) as Key

		_bindings[action] = key
		_write_key(action, key)

	_apply_volume()
	_apply_fullscreen()
	_apply_vsync()
	_sync_menu_navigation()
	changed.emit()


func _apply_volume() -> void:
	var bus_index := AudioServer.get_bus_index(MASTER_BUS)

	if bus_index < 0:
		return

	AudioServer.set_bus_volume_db(bus_index, linear_to_db(master_volume))
	AudioServer.set_bus_mute(bus_index, master_volume <= 0.0)


func _apply_fullscreen() -> void:
	# Window modes cannot change in headless runs (tests, servers).
	if DisplayServer.get_name() == "headless":
		return

	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


## The engine applies the project's V-Sync at startup, so loading only
## overrides it when the saved choice differs. Some drivers cannot change
## V-Sync and warn on every attempt.
func _apply_vsync(user_requested: bool = false) -> void:
	if DisplayServer.get_name() == "headless":
		return

	if not user_requested and vsync == DEFAULT_VSYNC:
		return

	var mode := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED

	# Only change it when needed: drivers without V-Sync control warn on every set.
	if DisplayServer.window_get_vsync_mode() != mode:
		DisplayServer.window_set_vsync_mode(mode)


func _is_menu_key_clash(action: StringName, key: Key) -> bool:
	if not MENU_ACTIVE_ACTIONS.has(action):
		return false

	for tab_action in MENU_TAB_ACTIONS:
		if InputMap.has_action(tab_action) and _ui_action_has_key(tab_action, key):
			return true

	return false


## Mirrors the movement keys onto the ui_* navigation actions. Only the keys
## this autoload added are replaced; built-in arrows and controller inputs stay.
func _sync_menu_navigation() -> void:
	for ui_action: StringName in MENU_NAVIGATION:
		if not InputMap.has_action(ui_action):
			continue

		var previous: InputEventKey = _menu_navigation_events.get(ui_action)

		if previous != null and InputMap.action_has_event(ui_action, previous):
			InputMap.action_erase_event(ui_action, previous)

		_menu_navigation_events.erase(ui_action)

		var key := get_binding(MENU_NAVIGATION[ui_action])

		if key == KEY_NONE or _ui_action_has_key(ui_action, key):
			continue

		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(ui_action, event)
		_menu_navigation_events[ui_action] = event


func _ui_action_has_key(ui_action: StringName, key: Key) -> bool:
	for event in InputMap.action_get_events(ui_action):
		var key_event := event as InputEventKey

		if key_event != null and (key_event.physical_keycode == key or key_event.keycode == key):
			return true

	return false


## Returns the action's keyboard key, preferring the physical keycode.
func _read_key(action: StringName) -> Key:
	if not InputMap.has_action(action):
		push_warning("Settings: Input action '%s' does not exist." % action)
		return KEY_NONE

	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey

		if key_event == null:
			continue

		return key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode

	return KEY_NONE


## Replaces the action's keyboard events and keeps controller events intact.
func _write_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		return

	if LINKED_ACTIONS.values().has(action):
		_write_linked_keys(action, key)

	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)

	if key == KEY_NONE:
		return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action, key_event)


## Gives every linked action the key its source action just received.
func _write_linked_keys(source: StringName, key: Key) -> void:
	for linked: StringName in LINKED_ACTIONS:
		if LINKED_ACTIONS[linked] == source:
			_write_key(linked, key)
