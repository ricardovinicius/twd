class_name DashMovementComponent
extends Node

## Owns one dash at a time: direction, speed profile, and duration, counted in
## physics ticks. The dash eases in from the body's current speed and eases out
## to a hand-off speed, so normal movement continues from where the dash ends
## instead of restarting from zero.

signal dash_started(direction: Vector2, peak_speed: float, duration: float)
signal dash_finished

## Absorbs float drift when summing physics deltas, so a dash lasts exactly
## round(duration / delta) ticks.
const DURATION_EPSILON := 0.0001

@export_category("Dash Profile")
## Fraction of the dash spent rising from the entry speed to the peak speed.
@export_range(0.0, 0.5, 0.01) var ease_in_ratio: float = 0.1
## Fraction of the dash spent settling from the peak speed to the exit speed.
@export_range(0.0, 1.0, 0.01) var ease_out_ratio: float = 0.35

var _direction: Vector2 = Vector2.ZERO
var _entry_speed: float = 0.0
var _peak_speed: float = 0.0
var _exit_speed: float = 0.0
var _duration: float = 0.0
var _elapsed: float = 0.0
var _is_active: bool = false


## Starts a dash. A dash never slows the body down: when it already moves
## faster than `speed` along `direction`, that speed becomes the peak.
## `exit_speed` is the speed handed back to normal movement at the end.
func begin(
	direction: Vector2,
	speed: float,
	duration: float,
	current_velocity: Vector2,
	exit_speed: float
) -> bool:
	if _is_active:
		return false

	if direction.is_zero_approx() or speed <= 0.0 or duration <= 0.0:
		push_error(
			"DashMovementComponent: Invalid dash (direction=%s, speed=%.1f, duration=%.2f)."
			% [direction, speed, duration]
		)
		return false

	_direction = direction.normalized()
	_entry_speed = maxf(current_velocity.dot(_direction), 0.0)
	_peak_speed = maxf(speed, _entry_speed)
	_exit_speed = clampf(exit_speed, 0.0, _peak_speed)
	_duration = duration
	_elapsed = 0.0
	_is_active = true

	dash_started.emit(_direction, _peak_speed, _duration)
	return true


## Advances the dash by one physics tick and returns its velocity. The last
## tick returns the exit velocity and finishes the dash.
func calculate_velocity(delta: float) -> Vector2:
	if not _is_active:
		return Vector2.ZERO

	_elapsed += delta

	if _elapsed >= _duration - DURATION_EPSILON:
		_elapsed = _duration

	var velocity := _direction * _speed_at(_elapsed / _duration)

	if _elapsed >= _duration:
		_finish()

	return velocity


func is_active() -> bool:
	return _is_active


func get_direction() -> Vector2:
	return _direction


func cancel() -> void:
	_finish()


func _speed_at(progress: float) -> float:
	var ease_out_start := 1.0 - ease_out_ratio

	if ease_out_ratio > 0.0 and progress > ease_out_start:
		var settle_weight := (progress - ease_out_start) / ease_out_ratio
		return lerpf(_peak_speed, _exit_speed, smoothstep(0.0, 1.0, settle_weight))

	if ease_in_ratio > 0.0 and progress < ease_in_ratio:
		# Fast start, soft arrival at the peak keeps the burst punchy.
		var rise_weight := progress / ease_in_ratio
		var eased_rise := 1.0 - (1.0 - rise_weight) * (1.0 - rise_weight)
		return lerpf(_entry_speed, _peak_speed, eased_rise)

	return _peak_speed


func _finish() -> void:
	if not _is_active:
		return

	_is_active = false
	_direction = Vector2.ZERO
	_elapsed = 0.0
	dash_finished.emit()
