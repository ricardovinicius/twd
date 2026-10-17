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

## Actions the player can rebind, in display order, with their labels.
const REMAPPABLE_ACTIONS: Array[Dictionary] = [
	{"action": &"left", "label": "Move left"},
	{"action": &"right", "label": "Move right"},
	{"action": &"aim_up", "label": "Aim up"},
	{"action": &"aim_down", "label": "Aim down / Drop down"},
	{"action": &"jump", "label": "Jump"},
	{"action": &"cast_move_token", "label": "Spell: Move token"},
	{"action": &"cast_interaction_token", "label": "Spell: Interaction token"},
	{"action": &"cast_attack_token", "label": "Spell: Attack token"},
	{"action": &"cast_confirm_token", "label": "Spell: Confirm"},
	{"action": &"interaction", "label": "Interact"},
	{"action": &"dialogue_cancel", "label": "Cancel / Back"},
	{"action": &"Select", "label": "Select"},
	{"action": &"pause", "label": "Pause"},
]

## Overridable so tests can write to an isolated file.
var settings_path: String = SETTINGS_PATH

var master_volume: float = DEFAULT_VOLUME
var fullscreen: bool = DEFAULT_FULLSCREEN

var _bindings: Dictionary[StringName, Key] = {}
var _default_bindings: Dictionary[StringName, Key] = {}


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


## Binds a physical key to an action. If another remappable action already
## uses that key, the two actions swap keys so no input is left ambiguous.
## Returns false for unknown actions or KEY_NONE.
func set_binding(action: StringName, key: Key) -> bool:
	if not _default_bindings.has(action) or key == KEY_NONE:
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
	changed.emit()

	return true


func reset_to_defaults() -> void:
	master_volume = DEFAULT_VOLUME
	fullscreen = DEFAULT_FULLSCREEN

	for action: StringName in _default_bindings:
		_bindings[action] = _default_bindings[action]
		_write_key(action, _default_bindings[action])

	_apply_volume()
	_apply_fullscreen()
	changed.emit()


func save_settings() -> bool:
	var file := ConfigFile.new()

	file.set_value(SECTION_AUDIO, "master_volume", master_volume)
	file.set_value(SECTION_VIDEO, "fullscreen", fullscreen)

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

	for action: StringName in _default_bindings:
		var key: Key = _default_bindings[action]

		if has_file:
			key = file.get_value(SECTION_INPUT, String(action), int(key)) as Key

		_bindings[action] = key
		_write_key(action, key)

	_apply_volume()
	_apply_fullscreen()
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

	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)

	if key == KEY_NONE:
		return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action, key_event)
