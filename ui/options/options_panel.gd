class_name OptionsPanel
extends VBoxContainer

## Audio, video, and control options, edited through the Settings autoload.
## Used by the main menu's Options screen and the pause menu's Settings tab.
## Changes apply immediately; call Settings.save_settings() to persist them.

const WAITING_TEXT := "Aperte uma tecla..."
const IDLE_HINT := "Escolha uma ação para trocar a tecla."
const CAPTURE_HINT := "Aperte a nova tecla. Esc cancela."

@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value_label: Label = %VolumeValueLabel
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var bindings_grid: GridContainer = %BindingsGrid
@onready var hint_label: Label = %HintLabel
@onready var reset_button: Button = %ResetButton

var _binding_buttons: Dictionary[StringName, Button] = {}
var _capturing_action: StringName = &""


func _ready() -> void:
	_build_binding_rows()
	refresh()

	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	reset_button.pressed.connect(_on_reset_pressed)
	Settings.changed.connect(refresh)


func _exit_tree() -> void:
	if Settings.changed.is_connected(refresh):
		Settings.changed.disconnect(refresh)


func _input(event: InputEvent) -> void:
	if _capturing_action.is_empty() or not is_visible_in_tree():
		return

	var key_event := event as InputEventKey

	if key_event == null or not key_event.pressed or key_event.is_echo():
		return

	get_viewport().set_input_as_handled()

	var key := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode

	# Escape cancels, except when rebinding Pause, which may use Escape itself.
	if key == KEY_ESCAPE and _capturing_action != &"pause":
		cancel_capture()
		return

	Settings.set_binding(_capturing_action, key)
	cancel_capture()


func focus_first() -> void:
	volume_slider.grab_focus()


## Starts waiting for the next key press to bind to the action.
func begin_capture(action: StringName) -> void:
	if not _binding_buttons.has(action):
		return

	cancel_capture()
	_capturing_action = action
	_binding_buttons[action].text = WAITING_TEXT
	hint_label.text = CAPTURE_HINT


func cancel_capture() -> void:
	var action := _capturing_action

	_capturing_action = &""
	hint_label.text = IDLE_HINT

	if _binding_buttons.has(action):
		_binding_buttons[action].text = Settings.get_key_label(action)
		_binding_buttons[action].grab_focus()


func is_capturing() -> bool:
	return not _capturing_action.is_empty()


func get_binding_button(action: StringName) -> Button:
	return _binding_buttons.get(action) as Button


func refresh() -> void:
	volume_slider.set_value_no_signal(Settings.master_volume * 100.0)
	volume_value_label.text = "%d%%" % roundi(Settings.master_volume * 100.0)
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	vsync_check.set_pressed_no_signal(Settings.vsync)

	for action: StringName in _binding_buttons:
		if action != _capturing_action:
			_binding_buttons[action].text = Settings.get_key_label(action)


func _build_binding_rows() -> void:
	for entry in Settings.REMAPPABLE_ACTIONS:
		var action: StringName = entry["action"]

		var label := Label.new()
		label.text = entry["label"]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bindings_grid.add_child(label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(200.0, 0.0)
		button.pressed.connect(begin_capture.bind(action))
		bindings_grid.add_child(button)

		_binding_buttons[action] = button


func _on_volume_changed(value: float) -> void:
	Settings.set_master_volume(value / 100.0)


func _on_fullscreen_toggled(enabled: bool) -> void:
	Settings.set_fullscreen(enabled)


func _on_vsync_toggled(enabled: bool) -> void:
	Settings.set_vsync(enabled)


func _on_reset_pressed() -> void:
	cancel_capture()
	Settings.reset_to_defaults()
