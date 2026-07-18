class_name DestroyOnDeath
extends Node

@export var health: Health
@export var target: Node


func _ready() -> void:
    # Guard Rails
    assert(health != null, "DestroyOnDeath: Health is not assigned.")
    assert(target != null, "DestroyOnDeath: Target is not assigned.")

    health.depleted.connect(_on_health_depleted)


func _on_health_depleted() -> void:
    # This could trigger an animation and sound as well
    target.queue_free()