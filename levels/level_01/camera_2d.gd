extends Camera2D

@export var look_offset: float = 120.0
@export var look_speed: float = 6.0
@export var hold_threshold: float = 0.15

var _hold_time: float = 0.0
var _holding_direction: int = 0

@onready var player: CharacterBody2D = get_parent()

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0

func _process(delta: float) -> void:
	var input_direction := 0

	if player.is_on_floor():
		if Input.is_action_pressed("aim_up"):
			input_direction = -1
		elif Input.is_action_pressed("aim_down"):
			input_direction = 1

	if input_direction != 0 and input_direction == _holding_direction:
		_hold_time += delta
	elif input_direction != 0:
		_holding_direction = input_direction
		_hold_time = 0.0
	else:
		_holding_direction = 0
		_hold_time = 0.0

	var target_offset_y := 0.0

	if _hold_time >= hold_threshold:
		target_offset_y = look_offset * _holding_direction

	offset.y = lerpf(offset.y, target_offset_y, look_speed * delta)
