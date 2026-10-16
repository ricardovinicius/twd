class_name PlatformCrawler
extends Node2D

## Inimigo que contorna uma plataforma em loop. Só enxerga o jogador à frente
## (no sentido em que anda) e com a linha de visão livre; quando o vê, acelera
## para atropelá-lo. Ao acertar, recua e investe de novo em vez de atravessá-lo.

enum State {
	PATROL,
	CHARGE,
	RECOIL,
}

signal state_changed(state: State)

@export_category("Platform")
## Tamanho da colisão da plataforma; a raiz fica no centro dela.
@export var platform_size: Vector2 = Vector2(192.0, 80.0)
@export_enum("Clockwise:1", "Counterclockwise:-1") var direction: int = 1
@export var start_distance: float = 0.0

@export_category("Movement")
@export_range(0.0, 2000.0, 1.0, "or_greater") var patrol_speed: float = 90.0
@export_range(0.0, 2000.0, 1.0, "or_greater") var charge_speed: float = 280.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var acceleration: float = 700.0

@export_category("Vision")
@export_range(0.0, 2000.0, 1.0, "or_greater") var vision_radius: float = 240.0
## Metade do cone de visão. 90° = toda a metade da frente.
@export_range(1.0, 180.0, 1.0) var vision_half_angle: float = 90.0
## Camadas que bloqueiam a visão (a própria plataforma e as paredes).
@export_flags_2d_physics var line_of_sight_mask: int = 1

@export_category("Attack")
## Quanto o mob volta pelo caminho depois de encostar no jogador.
@export_range(0.0, 500.0, 1.0, "or_greater") var recoil_distance: float = 48.0
@export_range(0.01, 5.0, 0.01, "or_greater") var recoil_duration: float = 0.2
## Pausa parado depois do recuo, antes de poder investir de novo.
@export_range(0.0, 5.0, 0.01, "or_greater") var attack_pause: float = 0.25

@export_category("Presentation")
@export var patrol_color: Color = Color(0.55, 0.35, 0.75)
@export var charge_color: Color = Color(0.95, 0.3, 0.3)

@onready var movement: PerimeterMovementComponent = $Movement
@onready var body: Node2D = $Body
@onready var visual: Node2D = $Body/Visual
@onready var vision: TargetDetector = $Body/Vision
@onready var vision_shape: CollisionShape2D = $Body/Vision/CollisionShape2D
@onready var contact_impact: ContactImpactComponent = $Body/ContactImpact
@onready var contact_area: Area2D = $Body/ContactImpact/ContactArea

var _state: State = State.PATROL
var _speed: float = 0.0
var _target: Node2D
var _recoil_time_left: float = 0.0
var _pause_time_left: float = 0.0


func _ready() -> void:
	movement.platform_size = platform_size
	movement.direction = direction
	movement.start_distance = start_distance
	movement.reset()

	var circle := vision_shape.shape as CircleShape2D
	if circle != null:
		# Cada instância ajusta o próprio raio sem mexer no recurso compartilhado.
		circle = circle.duplicate()
		circle.radius = vision_radius
		vision_shape.shape = circle

	contact_impact.contact_applied.connect(_on_contact_applied)
	visual.scale.x = signf(direction)
	_speed = patrol_speed
	_update_presentation()


func _physics_process(delta: float) -> void:
	if _state == State.RECOIL:
		_process_recoil(delta)
		return

	# Encostou no jogador à frente (mesmo sem dano, por cooldown): não atravessa.
	if _is_touching_target_ahead():
		start_recoil()
		return

	_target = _find_visible_target()
	_set_state(State.CHARGE if _target != null else State.PATROL)

	var desired_speed := charge_speed if _state == State.CHARGE else patrol_speed
	_speed = move_toward(_speed, desired_speed, acceleration * delta)
	movement.advance(_speed * delta)


func get_state() -> State:
	return _state


func get_speed() -> float:
	return _speed


func get_target() -> Node2D:
	return _target


func is_in_front(point: Vector2) -> bool:
	var offset := point - body.global_position
	if offset.is_zero_approx():
		return false

	return absf(movement.get_forward().angle_to(offset)) < deg_to_rad(vision_half_angle)


func has_line_of_sight(point: Vector2) -> bool:
	if line_of_sight_mask == 0 or not is_inside_tree():
		return true

	var query := PhysicsRayQueryParameters2D.create(body.global_position, point, line_of_sight_mask)
	query.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func can_see(target: Node2D) -> bool:
	return (
		is_instance_valid(target)
		and is_in_front(target.global_position)
		and has_line_of_sight(target.global_position)
	)


## Volta recoil_distance pelo caminho, para por attack_pause e então pode
## investir de novo. Ignorado se já estiver recuando.
func start_recoil() -> void:
	if _state == State.RECOIL:
		return

	_recoil_time_left = recoil_duration
	_pause_time_left = attack_pause
	_speed = 0.0
	_set_state(State.RECOIL)


func _process_recoil(delta: float) -> void:
	if _recoil_time_left > 0.0:
		var step := minf(delta, _recoil_time_left)
		_recoil_time_left -= step
		movement.advance(-recoil_distance * step / recoil_duration)
		return

	_pause_time_left -= delta
	if _pause_time_left > 0.0:
		return

	# Recomeça parado, para acelerar de novo como uma nova investida.
	_speed = 0.0
	_set_state(State.PATROL)


func _find_visible_target() -> Node2D:
	var closest: Node2D = null
	var closest_distance := INF

	for candidate in vision.get_targets():
		if not can_see(candidate):
			continue

		var candidate_distance := body.global_position.distance_squared_to(candidate.global_position)
		if candidate_distance < closest_distance:
			closest = candidate
			closest_distance = candidate_distance

	return closest


func _is_touching_target_ahead() -> bool:
	var forward := movement.get_forward()

	for overlapping in contact_area.get_overlapping_bodies():
		if not overlapping.is_in_group(contact_impact.target_group):
			continue
		if (overlapping.global_position - body.global_position).dot(forward) > 0.0:
			return true

	return false


func _on_contact_applied(_contact_target: Node2D) -> void:
	start_recoil()


func _set_state(new_state: State) -> void:
	if new_state == _state:
		return

	_state = new_state
	_update_presentation()
	state_changed.emit(_state)


func _update_presentation() -> void:
	visual.modulate = patrol_color if _state == State.PATROL else charge_color
