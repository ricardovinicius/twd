class_name CoinPickup
extends Area2D

## Quantidade de Stardust adicionada ao ser coletado.
@export_range(1, 1000) var amount: int = 1
@export var player_group: StringName = &"player"
## Opcional: faz o pickup cair até o chão. Sem ele, o pickup flutua parado.
@export var fall: PickupFallComponent

@onready var animated_sprite_2d = $AnimatedSprite2D

var player: Node2D = null
var attraction_speed := 300.0
var collected := false
var _is_attracted := false


func _ready() -> void:
	PersistentPickup.register(self)


func _physics_process(delta):
	if not _is_attracted:
		return

	if not is_instance_valid(player):
		_stop_attraction()
		return

	global_position = global_position.move_toward(
		player.global_position,
		attraction_speed * delta
	)


func _on_attraction_area_body_entered(body):
	if not body.is_in_group(player_group):
		return

	player = body
	_is_attracted = true

	# A atração move o pickup; a queda volta se o jogador sumir.
	if fall != null:
		fall.set_suspended(true)


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


func _stop_attraction() -> void:
	player = null
	_is_attracted = false

	if fall != null:
		fall.set_suspended(false)
