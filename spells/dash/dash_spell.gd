class_name DashSpell
extends SpellCommand

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
	
	await context.caster.begin_dash(context.direction, speed, duration)

	# End Guard clauses
	# ===================

	complete()
