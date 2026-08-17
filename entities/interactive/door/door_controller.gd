class_name DoorController
extends Node2D

signal door_state_changed(state: State)

enum State {
	CLOSED,
	OPENING,
	OPEN,
	WAITING_TO_CLOSE,
	CLOSING,
}

@export var switch: SwitchComponent
@export var animation_player: AnimationPlayer
@export var door_body: AnimatableBody2D
@export var door_collision: CollisionShape2D
@export var doorway_detector: Area2D
@export var open_animation := &"open"
@export var close_animation := &"close"
@export var closed_position := Vector2(0, -48)
@export var open_position := Vector2(0, -152)

var state := State.CLOSED
var _desired_open := false


func _ready() -> void:
	if not _has_required_references():
		push_error("DoorController is missing one or more required references.")
		return

	switch.state_changed.connect(_on_switch_state_changed)
	animation_player.animation_finished.connect(_on_animation_finished)
	doorway_detector.body_entered.connect(_on_doorway_body_entered)
	doorway_detector.body_exited.connect(_on_doorway_body_exited)
	_apply_initial_state(switch.active)


func _has_required_references() -> bool:
	return (
		switch != null
		and animation_player != null
		and door_body != null
		and door_collision != null
		and doorway_detector != null
	)


func _apply_initial_state(open: bool) -> void:
	_desired_open = open
	animation_player.stop()
	door_body.position = open_position if open else closed_position
	door_collision.disabled = open
	_set_state(State.OPEN if open else State.CLOSED)


func _on_switch_state_changed(open: bool) -> void:
	_desired_open = open
	if open:
		_begin_opening()
	else:
		_request_close()


func _begin_opening() -> void:
	if state == State.OPEN or state == State.OPENING:
		return

	if state != State.CLOSED:
		door_collision.set_deferred("disabled", true)

	_set_state(State.OPENING)
	_play_transition(true)


func _request_close() -> void:
	if state == State.CLOSED or state == State.CLOSING:
		return

	if _is_doorway_occupied():
		if state == State.OPENING:
			return
		_set_state(State.WAITING_TO_CLOSE)
		return

	_begin_closing()


func _begin_closing() -> void:
	if state == State.CLOSED or state == State.CLOSING:
		return

	_set_state(State.CLOSING)
	_play_transition(false)


func _play_transition(opening: bool) -> void:
	var openness := _get_animation_openness()
	var animation_name := open_animation if opening else close_animation
	var animation := animation_player.get_animation(animation_name)
	animation_player.play(animation_name)
	var start_position := animation.length * (openness if opening else 1.0 - openness)
	if start_position > 0.0:
		animation_player.seek(start_position)


func _get_animation_openness() -> float:
	if not animation_player.is_playing():
		return _get_door_body_openness()

	var current_animation := animation_player.current_animation
	if current_animation == open_animation:
		var animation := animation_player.get_animation(open_animation)
		return clampf(animation_player.current_animation_position / animation.length, 0.0, 1.0)

	if current_animation == close_animation:
		var animation := animation_player.get_animation(close_animation)
		return 1.0 - clampf(animation_player.current_animation_position / animation.length, 0.0, 1.0)

	return _get_door_body_openness()


func _get_door_body_openness() -> float:
	var travel := open_position - closed_position
	if travel.is_zero_approx():
		return 1.0

	var current_offset := door_body.position - closed_position
	return clampf(current_offset.dot(travel) / travel.length_squared(), 0.0, 1.0)


func release_collision() -> void:
	if state == State.OPENING or state == State.OPEN:
		door_collision.set_deferred("disabled", true)


func try_restore_collision() -> void:
	if state != State.CLOSING or _desired_open:
		return

	if _is_doorway_occupied():
		_begin_opening()
		return

	door_collision.set_deferred("disabled", false)


func _on_animation_finished(animation_name: StringName) -> void:
	if state == State.OPENING and animation_name == open_animation:
		release_collision()
		_set_state(State.OPEN)
		if not _desired_open:
			if _is_doorway_occupied():
				_set_state(State.WAITING_TO_CLOSE)
			else:
				_begin_closing()
	elif state == State.CLOSING and animation_name == close_animation:
		if _desired_open:
			_begin_opening()
		elif _is_doorway_occupied():
			door_collision.set_deferred("disabled", true)
			_begin_opening()
		else:
			try_restore_collision()
			_set_state(State.CLOSED)


func _on_doorway_body_entered(_body: Node2D) -> void:
	if state == State.CLOSING:
		_begin_opening()


func _on_doorway_body_exited(_body: Node2D) -> void:
	if state == State.WAITING_TO_CLOSE and not _desired_open and not _is_doorway_occupied():
		_begin_closing()


func _is_doorway_occupied() -> bool:
	return not doorway_detector.get_overlapping_bodies().is_empty()


func _set_state(value: State) -> void:
	if state == value:
		return

	state = value
	door_state_changed.emit(state)
