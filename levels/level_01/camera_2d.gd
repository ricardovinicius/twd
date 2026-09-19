extends Camera2D

@export var look_offset: float = 120.0   # o quanto a câmera se desloca ao olhar pra cima/baixo
@export var look_speed: float = 6.0      # velocidade de interpolação do offset

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0  # <- esse número É o seu "delayzinho". Menor = mais delay/mole

func _process(delta: float) -> void:
	var target_offset_y := 0.0

	if Input.is_action_pressed("look_up"):
		target_offset_y = -look_offset
	elif Input.is_action_pressed("look_down"):
		target_offset_y = look_offset

	offset.y = lerpf(offset.y, target_offset_y, look_speed * delta)
