class_name JumpBufferComponent
extends Timer


func _ready() -> void:
	one_shot = true
	process_callback = Timer.TIMER_PROCESS_PHYSICS


func buffer_jump() -> void:
	start()


func is_jump_buffered() -> bool:
	return time_left > 0.0


func consume_jump() -> void:
	stop()
