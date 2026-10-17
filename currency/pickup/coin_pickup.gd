class_name CoinPickup
extends Area2D

## Quantidade de Stardust adicionada ao ser coletado.
@export_range(1, 1000) var amount: int = 1
@export var player_group: StringName = &"player"

@onready var animated_sprite_2d = $AnimatedSprite2D

var player: Node2D = null
var attraction_speed := 300.0
var collected := false


func _ready() -> void:
	PersistentPickup.register(self)


func _physics_process(delta):
	if not is_instance_valid(player):
		player = null
		return

	global_position = global_position.move_toward(
		player.global_position,
		attraction_speed * delta
	)


func _on_attraction_area_body_entered(body):
	if body.is_in_group(player_group):
		player = body


func _on_body_entered(body):
	# Chão e inimigos também entram na área; só o jogador coleta.
	if collected or not body.is_in_group(player_group):
		return

	collected = true

	CoinManager.add_coins(amount)
	SaveGame.mark_collected(self)

	animated_sprite_2d.play("collected")

	await animated_sprite_2d.animation_finished

	queue_free()
