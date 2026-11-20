class_name BreakableShield
extends Node

## A shield that must be broken with a burst of damage. While it is up it takes
## all the damage meant for Health. Dealing `maximum` damage within
## `break_window` seconds of the first hit breaks it; if the window runs out
## first, it snaps back to full. Once broken, damage goes straight to Health,
## and the shield comes back at full strength after `regen_delay` seconds
## without being hit.
##
## Assign it to `Health.breakable_shield`; Health routes every damage source
## (spells, projectiles, burning, contact) through `absorb()`.

signal changed(current: float, maximum: float)
## Damage the intact shield took from one hit.
signal hit(absorbed: float)
signal broken
signal restored

@export_category("Breakable Shield")
## Damage needed within the break window to break the shield.
@export_range(1.0, 1000.0, 1.0, "or_greater") var maximum: float = 50.0
## Seconds after the first hit to finish breaking it before it refills.
@export_range(0.1, 30.0, 0.1, "or_greater") var break_window: float = 1.0
## Seconds without hits, once broken, before it comes back at full strength.
@export_range(0.1, 60.0, 0.1, "or_greater") var regen_delay: float = 4.0

var current: float = 0.0

var _is_broken: bool = false
var _window_time_left: float = 0.0
var _regen_time_left: float = 0.0


func _ready() -> void:
	current = maximum


func _physics_process(delta: float) -> void:
	if _is_broken:
		_regen_time_left -= delta

		if _regen_time_left <= 0.0:
			reset()

		return

	if _window_time_left > 0.0:
		_window_time_left -= delta

		if _window_time_left <= 0.0:
			_refill()


## Takes what damage it can and returns the damage that passes through to
## Health. A hit that breaks the shield passes its leftover damage through.
func absorb(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	if _is_broken:
		# Any hit while broken delays the regeneration.
		_regen_time_left = regen_delay
		return amount

	if _window_time_left <= 0.0:
		_window_time_left = break_window

	var absorbed := minf(current, amount)

	current -= absorbed
	hit.emit(absorbed)
	changed.emit(current, maximum)

	if current <= 0.0:
		_break()

	return amount - absorbed


func is_broken() -> bool:
	return _is_broken


func get_ratio() -> float:
	return current / maximum if maximum > 0.0 else 0.0


func get_window_time_left() -> float:
	return maxf(_window_time_left, 0.0)


func get_regen_time_left() -> float:
	return maxf(_regen_time_left, 0.0) if _is_broken else 0.0


## Breaks the shield at once, whatever its strength (the Break spell). Returns
## false when it is already broken.
func shatter() -> bool:
	if _is_broken:
		return false

	_break()
	changed.emit(current, maximum)

	return true


## Brings the shield back to full strength immediately (also used by
## Health.reset() on respawn).
func reset() -> void:
	var was_broken := _is_broken

	_is_broken = false
	_window_time_left = 0.0
	_regen_time_left = 0.0
	current = maximum
	changed.emit(current, maximum)

	if was_broken:
		restored.emit()


func _break() -> void:
	_is_broken = true
	current = 0.0
	_window_time_left = 0.0
	_regen_time_left = regen_delay
	broken.emit()


func _refill() -> void:
	_window_time_left = 0.0

	if current >= maximum:
		return

	current = maximum
	changed.emit(current, maximum)
