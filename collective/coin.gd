extends Area2D

@onready var animated_sprite_2d = $AnimatedSprite2D

var player = null
var attraction_speed := 300.0
var collected := false


func _process(delta):
	if player != null:
		global_position = global_position.move_toward(
			player.global_position,
			attraction_speed * delta
		)


func _on_attraction_area_body_entered(body):
	if body is CharacterBody2D:
		player = body


func _on_body_entered(_body):
	if collected:
		return

	collected = true

	CoinManager.add_coin()

	animated_sprite_2d.play("collected")

	await animated_sprite_2d.animation_finished

	queue_free()
