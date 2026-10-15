class_name CoyoteTimeComponent
extends Timer

var _jump_consumed_since_grounded: bool = false


func _ready() -> void:
	one_shot = true
	process_callback = Timer.TIMER_PROCESS_PHYSICS


func can_jump(is_on_floor: bool) -> bool:
	if _jump_consumed_since_grounded:
		return false

	return is_on_floor or time_left > 0.0


func consume_jump() -> void:
	_jump_consumed_since_grounded = true
	stop()


func update_floor_state(was_on_floor: bool, is_on_floor: bool) -> void:
	if is_on_floor:
		_jump_consumed_since_grounded = false
		stop()
	elif was_on_floor and not _jump_consumed_since_grounded:
		start()
