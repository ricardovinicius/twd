class_name DoubleJumpSpell
extends SpellCommand


func _execute() -> void:
	if context == null or context.caster == null:
		fail(&"missing_caster")
		return

	if not context.caster.has_method(&"try_spell_jump"):
		fail(&"unsupported_caster")
		return

	var jumped: bool = context.caster.try_spell_jump()
	if not jumped:
		fail(&"jump_failed")
		return

	complete()
