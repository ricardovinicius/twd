class_name ShieldVisual
extends Node2D

## Placeholder look for a BreakableShield: a translucent bubble around its
## owner that fades as the shield takes damage, a bar above it during a break
## attempt, and a quick burst when it breaks. Hidden while broken.

@export var shield: BreakableShield
## Bubble size in this node's local units, centered on the node.
@export var size: Vector2 = Vector2(20.0, 36.0)
@export var color: Color = Color(0.45, 0.82, 1.0)
## Gap between the bubble and the bar above it.
@export var bar_gap: float = 3.0
@export var bar_height: float = 2.0
@export var break_flash_duration: float = 0.25

var _flash_time_left: float = 0.0


func _ready() -> void:
	if shield == null:
		push_error("ShieldVisual: BreakableShield is not assigned.")
		return

	shield.changed.connect(_on_shield_changed)
	shield.broken.connect(_on_shield_broken)
	shield.restored.connect(queue_redraw)


func _process(delta: float) -> void:
	if _flash_time_left <= 0.0:
		return

	_flash_time_left -= delta
	queue_redraw()


func _draw() -> void:
	if shield == null:
		return

	var bubble := Rect2(-size * 0.5, size)

	if _flash_time_left > 0.0:
		_draw_break_flash(bubble)

	if shield.is_broken():
		return

	var ratio := shield.get_ratio()

	draw_rect(bubble, Color(color, 0.1 + 0.15 * ratio))
	draw_rect(bubble, Color(color, 0.35 + 0.65 * ratio), false, 1.0)

	if ratio < 1.0:
		_draw_bar(bubble, ratio)


func _draw_bar(bubble: Rect2, ratio: float) -> void:
	var bar := Rect2(
		bubble.position.x,
		bubble.position.y - bar_gap - bar_height,
		bubble.size.x,
		bar_height
	)
	var filled := Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y))

	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(filled, color)


func _draw_break_flash(bubble: Rect2) -> void:
	var progress := 1.0 - _flash_time_left / break_flash_duration

	draw_rect(bubble.grow(1.0 + 5.0 * progress), Color(1.0, 1.0, 1.0, 1.0 - progress), false, 1.0)


func _on_shield_changed(_current: float, _maximum: float) -> void:
	queue_redraw()


func _on_shield_broken() -> void:
	_flash_time_left = break_flash_duration
	queue_redraw()
