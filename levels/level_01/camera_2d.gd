extends Camera2D

@export_category("Follow")
## Quão rápido a câmera alcança o jogador. Maior = mais colada.
@export var follow_speed: float = 7.0

@export_category("Look Ahead")
## Distância que a câmera se adianta na direção em que o jogador está indo.
@export var look_ahead_distance: float = 140.0
## Quão rápido o adiantamento horizontal acompanha a troca de direção.
@export var look_ahead_speed: float = 2.5
## Velocidade horizontal mínima para considerar que o jogador mudou de direção.
@export var look_ahead_min_speed: float = 10.0

@export_category("Fall")
## Velocidade de queda a partir da qual a câmera começa a olhar para baixo.
@export var fall_look_threshold: float = 450.0
## Quanto a câmera desce por unidade de velocidade de queda acima do limite.
@export var fall_look_factor: float = 0.3
## Deslocamento máximo para baixo durante uma queda.
@export var fall_look_max: float = 160.0
@export var fall_look_speed: float = 4.0

@export_category("Look Up/Down")
@export var look_offset: float = 120.0
@export var look_speed: float = 6.0
@export var hold_threshold: float = 0.15

var _hold_time: float = 0.0
var _holding_direction: int = 0
var _facing: float = 1.0
var _look_ahead_x: float = 0.0
var _fall_y: float = 0.0
var _look_y: float = 0.0
var _base_offset: Vector2

@onready var player: CharacterBody2D = get_parent()


func _ready() -> void:
	_base_offset = offset
	# A câmera segue o jogador continuamente; drag margins a deixavam parada
	# até o jogador chegar perto da borda da tela.
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	position_smoothing_enabled = true
	position_smoothing_speed = follow_speed
	# Atualiza junto com a física (60 Hz) para a interpolação suavizar o movimento
	# em monitores com outra taxa de atualização (ex.: 74/144 Hz) sem tremer.
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func _physics_process(delta: float) -> void:
	_update_look_ahead(delta)
	_update_fall_look(delta)
	_update_look_up_down(delta)

	offset = _base_offset + Vector2(_look_ahead_x, _fall_y + _look_y)


func _update_look_ahead(delta: float) -> void:
	if absf(player.velocity.x) > look_ahead_min_speed:
		_facing = signf(player.velocity.x)

	_look_ahead_x = _smooth(_look_ahead_x, _facing * look_ahead_distance, look_ahead_speed, delta)


func _update_fall_look(delta: float) -> void:
	var target_fall_y := 0.0

	if not player.is_on_floor() and player.velocity.y > fall_look_threshold:
		target_fall_y = minf(
			(player.velocity.y - fall_look_threshold) * fall_look_factor,
			fall_look_max
		)

	_fall_y = _smooth(_fall_y, target_fall_y, fall_look_speed, delta)


func _update_look_up_down(delta: float) -> void:
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

	var target_look_y := 0.0

	if _hold_time >= hold_threshold:
		target_look_y = look_offset * _holding_direction

	_look_y = _smooth(_look_y, target_look_y, look_speed, delta)


# Interpolação independente do framerate.
func _smooth(current: float, target: float, speed: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-speed * delta))
