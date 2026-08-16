class_name PlayerHud
extends Control

@export var health: Health

@onready var health_bar: TextureProgressBar = %HealthBar


func _ready() -> void:
	assert(health != null, "PlayerHud: Health is not assigned.")

	health.changed.connect(_on_health_changed)
	_update_health_bar(health.current, health.maximum)


func _on_health_changed(current: float, maximum: float) -> void:
	_update_health_bar(current, maximum)


func _update_health_bar(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
