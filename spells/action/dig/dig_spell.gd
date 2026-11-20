class_name DigSpell
extends ActionSpell

## Damage applied to each diggable target. Diggable blocks with one point of
## health break with a single cast.
@export_range(0.0, 100.0, 1.0, "or_greater") var dig_strength: float = 1.0

## Magic slash shown where the dig reaches. It is a child of EffectQuery, so it
## is placed and rotated with the dig's aim.
@onready var slash: AnimatedSprite2D = $EffectQuery/Slash


func _execute() -> void:
	# ActionSpell aims the effect query before it waits for completion, so the
	# slash is already in place when it plays.
	super._execute()

	if _is_finished:
		return

	_play_slash()


func _play_slash() -> void:
	slash.visible = true
	slash.play(&"slash")
	slash.animation_finished.connect(slash.hide, CONNECT_ONE_SHOT)


func _get_effect_direction() -> Vector2:
	if not context.aim_direction.is_zero_approx():
		return context.aim_direction.normalized()

	return context.direction.normalized()


func _create_action_for(_receiver: ActionReceiver) -> ActionData:
	if context == null:
		return null

	var action := ActionData.new()

	action.type = &"dig"
	action.source = context.caster
	action.origin = context.origin
	action.direction = _get_effect_direction()
	action.strength = dig_strength

	return action
