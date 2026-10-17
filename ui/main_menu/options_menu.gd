class_name OptionsMenu
extends Control

## Presents and edits the options owned by the Settings autoload. Changes
## apply immediately and are saved when the screen closes.

const MAIN_MENU_SCENE := "res://ui/main_menu/MainMenu.tscn"
const WAITING_TEXT := "Press a key..."

@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value_label: Label = %VolumeValueLabel
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var bindings_grid: GridContainer = %BindingsGrid
@onready var hint_label: Label = %HintLabel
@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton

var _binding_buttons: Dictionary[StringName, Button] = {}
var _capturing_action: StringName = &""


func _ready() -> void:
	_build_binding_rows()
	_refresh()

	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(close)
	Settings.changed.connect(_refresh)

	volume_slider.grab_focus()


func _exit_tree() -> void:
	if Settings.changed.is_connected(_refresh):
		Settings.changed.disconnect(_refresh)

	Settings.save_settings()


func _input(event: InputEvent) -> void:
	if _capturing_action.is_empty():
		return

	var key_event := event as InputEventKey

	if key_event == null or not key_event.pressed or key_event.is_echo():
		return

	get_viewport().set_input_as_handled()

	var key := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode

	# Escape cancels, except when rebinding Pause, which may use Escape itself.
	if key == KEY_ESCAPE and _capturing_action != &"pause":
		_stop_capture()
		return

	Settings.set_binding(_capturing_action, key)
	_stop_capture()


func _unhandled_input(event: InputEvent) -> void:
	if not _capturing_action.is_empty():
		return

	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Starts waiting for the next key press to bind to the action.
func begin_capture(action: StringName) -> void:
	if not _binding_buttons.has(action):
		return

	_stop_capture()
	_capturing_action = action
	_binding_buttons[action].text = WAITING_TEXT
	hint_label.text = "Press the new key. Esc cancels."


func is_capturing() -> bool:
	return not _capturing_action.is_empty()


func get_binding_button(action: StringName) -> Button:
	return _binding_buttons.get(action) as Button


func _stop_capture() -> void:
	var action := _capturing_action

	_capturing_action = &""
	hint_label.text = "Select an action to change its key."

	if _binding_buttons.has(action):
		_binding_buttons[action].text = Settings.get_key_label(action)
		_binding_buttons[action].grab_focus()


func _build_binding_rows() -> void:
	for entry in Settings.REMAPPABLE_ACTIONS:
		var action: StringName = entry["action"]

		var label := Label.new()
		label.text = entry["label"]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bindings_grid.add_child(label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(180.0, 0.0)
		button.pressed.connect(begin_capture.bind(action))
		bindings_grid.add_child(button)

		_binding_buttons[action] = button


func _refresh() -> void:
	volume_slider.set_value_no_signal(Settings.master_volume * 100.0)
	volume_value_label.text = "%d%%" % roundi(Settings.master_volume * 100.0)
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)

	for action: StringName in _binding_buttons:
		if action != _capturing_action:
			_binding_buttons[action].text = Settings.get_key_label(action)


func _on_volume_changed(value: float) -> void:
	Settings.set_master_volume(value / 100.0)


func _on_fullscreen_toggled(enabled: bool) -> void:
	Settings.set_fullscreen(enabled)


func _on_reset_pressed() -> void:
	_stop_capture()
	Settings.reset_to_defaults()
