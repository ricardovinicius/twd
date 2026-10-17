class_name LoadingSpinner
extends Control

## A rotating arc drawn in code, used as a lightweight loading indicator.

@export var color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export_range(1.0, 16.0, 0.5) var thickness: float = 4.0
## Full turns per second.
@export_range(0.1, 5.0, 0.1) var speed: float = 1.2

var _angle: float = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	_angle = fmod(_angle + TAU * speed * delta, TAU)
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5 - thickness
	var center := size * 0.5

	draw_arc(center, radius, 0.0, TAU, 48, Color(color, color.a * 0.2), thickness, true)
	draw_arc(center, radius, _angle, _angle + TAU * 0.3, 24, color, thickness, true)
