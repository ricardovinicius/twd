class_name DamageAnimation
extends Node

@export var health: Health
@export var sprite: AnimatedSprite2D
@export var hit_animation: StringName = &"hit"
@export var default_animation: StringName = &"idle"


func _ready() -> void:
	# Guard clauses to ensure that the required nodes are assigned.
	print(health)
	assert(health != null, "DamageAnimation: Health node is not assigned.")
	assert(sprite != null, "DamageAnimation: AnimatedSprite2D node is not assigned.")

	health.damaged.connect(_on_damaged)
	sprite.animation_finished.connect(_on_animation_finished)


func _on_damaged(_amount: float) -> void:
	if _amount <= 0.0:
		return

	sprite.play(hit_animation)
	sprite.set_frame_and_progress(0, 0.0)  # Reset the animation to the first frame


func _on_animation_finished() -> void:
	if sprite.animation == hit_animation:
		sprite.play(default_animation)
		sprite.set_frame_and_progress(0, 0.0)  # Reset the animation to the first frame
