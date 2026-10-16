class_name PerimeterMovementComponent
extends Node

## Move o body em volta do retângulo de uma plataforma (centrada na origem do
## pai do body), encostado na superfície e girado para ficar "de pé" sobre ela.
## A distância 0 é a ponta esquerda da borda de cima; aumentar = sentido horário.

@export var body: Node2D
## Tamanho da colisão da plataforma.
@export var platform_size: Vector2 = Vector2(192.0, 80.0)
## Distância do centro do body até a superfície (meia altura do corpo).
@export_range(0.0, 200.0) var clearance: float = 12.0
@export_enum("Clockwise:1", "Counterclockwise:-1") var direction: int = 1
@export var start_distance: float = 0.0

var distance: float = 0.0


func _ready() -> void:
	if body == null:
		push_error("PerimeterMovementComponent: Body is not assigned.")
		return

	reset()


func reset() -> void:
	distance = wrapf(start_distance, 0.0, get_perimeter_length())
	_apply()


func get_perimeter_length() -> float:
	var size := platform_size.max(Vector2.ZERO)
	return 2.0 * (size.x + size.y) + TAU * clearance


## Positivo anda para a frente (no sentido de `direction`); negativo, para trás.
func advance(step: float) -> void:
	distance = wrapf(distance + step * signf(direction), 0.0, get_perimeter_length())
	_apply()


func get_forward() -> Vector2:
	if body == null:
		return Vector2.RIGHT * signf(direction)

	# O eixo x do body é a tangente no sentido horário.
	return body.global_transform.x.normalized() * signf(direction)


func sample(at: float) -> Transform2D:
	var size := platform_size.max(Vector2.ZERO)
	var half := size * 0.5
	var length := get_perimeter_length()
	if length <= 0.0:
		return Transform2D.IDENTITY

	var remaining := wrapf(at, 0.0, length)
	var corners: Array[Vector2] = [
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
		Vector2(-half.x, -half.y),
	]
	var edges: Array[float] = [size.x, size.y, size.x, size.y]
	var arc_length := clearance * PI * 0.5

	for side in 4:
		# Normal da borda: cima, direita, baixo, esquerda.
		var normal_angle := -PI * 0.5 + PI * 0.5 * side
		var normal := Vector2.from_angle(normal_angle)
		var tangent := normal.rotated(PI * 0.5)

		if remaining <= edges[side]:
			var point := corners[side] + normal * clearance - tangent * (edges[side] - remaining)
			return Transform2D(normal_angle + PI * 0.5, point)
		remaining -= edges[side]

		if remaining <= arc_length or side == 3:
			var angle := normal_angle
			if clearance > 0.0:
				angle += minf(remaining, arc_length) / clearance
			return Transform2D(angle + PI * 0.5, corners[side] + Vector2.from_angle(angle) * clearance)
		remaining -= arc_length

	return Transform2D.IDENTITY


func _apply() -> void:
	if body != null:
		body.transform = sample(distance)
