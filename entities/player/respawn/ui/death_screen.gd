class_name DeathScreen
extends CanvasLayer

## Covers the screen after the player dies and shows a loading indicator in
## the bottom-right corner while the respawn happens behind it. Gameplay is
## paused and input is blocked until the screen fades out.

signal finished

## Seconds the loading screen stays up before fading out.
@export_range(0.0, 30.0, 0.1, "or_greater") var duration: float = 5.0
## Seconds the black overlay takes to fade out.
@export_range(0.0, 3.0, 0.05) var fade_out_time: float = 0.5

@onready var overlay: ColorRect = $Overlay
@onready var loading: Control = $Loading
@onready var loading_label: Label = %LoadingLabel

var _active: bool = false
var _generation: int = 0
var _elapsed: float = 0.0
var _paused_by_us: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hide_immediately()
	Events.player_died.connect(show_death)


func _exit_tree() -> void:
	if Events.player_died.is_connected(show_death):
		Events.player_died.disconnect(show_death)

	_release_pause()


func _process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta
	var dots := int(_elapsed * 2.0) % 4
	loading_label.text = "Loading" + ".".repeat(dots)


func _input(event: InputEvent) -> void:
	# Block gameplay and the pause menu until the player is back.
	if _active:
		get_viewport().set_input_as_handled()


func is_active() -> bool:
	return _active


## Shows the loading screen immediately; it fades out after `duration`.
func show_death() -> void:
	_generation += 1
	var generation := _generation

	_active = true
	_elapsed = 0.0
	overlay.modulate.a = 1.0
	overlay.show()
	loading.show()
	loading_label.text = "Loading"

	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true

	await get_tree().create_timer(duration, true, false, true).timeout

	if generation != _generation or not is_inside_tree():
		return

	await _fade_out()

	if generation != _generation:
		return

	_finish()


func _fade_out() -> void:
	loading.hide()
	_release_pause()

	if fade_out_time <= 0.0:
		return

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "modulate:a", 0.0, fade_out_time)
	await tween.finished


func _finish() -> void:
	_hide_immediately()
	finished.emit()


func _hide_immediately() -> void:
	_active = false
	overlay.hide()
	overlay.modulate.a = 0.0
	loading.hide()


func _release_pause() -> void:
	if _paused_by_us and is_inside_tree():
		get_tree().paused = false

	_paused_by_us = false
