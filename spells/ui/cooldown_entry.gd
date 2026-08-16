class_name CooldownEntry
extends Control

@onready var spell_icon: TextureRect = %SpellIcon
@onready var cooldown_overlay: ColorRect = %CooldownOverlay

var spell_id: StringName
var duration: float


func setup(spell: SpellDefinition, cooldown_duration: float) -> void:
	spell_id = spell.id
	duration = cooldown_duration
	spell_icon.texture = spell.icon

	if spell.icon == null:
		push_warning("CooldownEntry: Spell '%s' has no representative icon." % spell.id)

	set_remaining_ratio(1.0)


func set_remaining(remaining_seconds: float) -> void:
	if duration <= 0.0:
		set_remaining_ratio(0.0)
		return

	set_remaining_ratio(remaining_seconds / duration)


func set_remaining_ratio(ratio: float) -> void:
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	cooldown_overlay.anchor_top = 1.0 - clamped_ratio
	cooldown_overlay.offset_top = 0.0
