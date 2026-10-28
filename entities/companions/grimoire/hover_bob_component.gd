class_name HoverBobComponent
extends Node

## Presentation only: bobs and sways a visual node so a floating companion
## looks alive. It moves the visual, never the companion's position.

@export var visual: Node2D

@export_category("Hover")
@export_range(0.0, 64.0, 0.5, "or_greater") var bob_height: float = 6.0
@export_range(0.1, 10.0, 0.05, "or_greater") var bob_period: float = 1.6
## Maximum sway in degrees, in step with the bob.
@export_range(0.0, 45.0, 0.5) var sway_degrees: float = 4.0

var _elapsed: float = 0.0
var _rest_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	if visual == null:
		push_error("HoverBobComponent: Visual is not assigned.")
		set_physics_process(false)
		return

	_rest_position = visual.position


# Runs with physics so the visual moves on the same ticks as the interpolated
# companion body.
func _physics_process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, bob_period)
	var phase := TAU * _elapsed / bob_period

	visual.position = _rest_position + Vector2(0.0, sin(phase) * bob_height)
	visual.rotation = deg_to_rad(sway_degrees) * cos(phase)
