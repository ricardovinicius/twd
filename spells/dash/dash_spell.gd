class_name DashSpell
extends SpellCommand

## Dash speed as a multiple of the caster's current move speed, so move speed
## bonuses (equipment, stats) make the dash faster too and it always outpaces
## walking. 1.25 keeps the original 500 px/s at the base move speed of 400.
@export_range(0.1, 10.0, 0.05, "or_greater") var move_speed_multiplier: float = 1.25
## Used only when the caster does not expose `get_move_speed()`.
@export var speed: float = 500.0
@export var duration: float = 0.2


func _execute() -> void:
	# Guard clauses
	# ===================
	if context == null or not is_instance_valid(context.caster):
		fail(&"missing_caster")
		return

	# TODO: Maybe we could compose the caster with a Dashable interface instead of checking for the method directly.
	if not context.caster.has_method("begin_dash"):
		fail(&"unsupported_caster")
		return
	
	await context.caster.begin_dash(context.direction, _get_dash_speed(), duration)

	# End Guard clauses
	# ===================

	complete()


func _get_dash_speed() -> float:
	if not context.caster.has_method("get_move_speed"):
		return speed

	return context.caster.get_move_speed() * move_speed_multiplier
