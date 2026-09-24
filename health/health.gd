class_name Health
extends Node

signal changed(current: float, maximum: float)
signal damaged(amount: float)
signal depleted
signal shield_changed(current: float, maximum: float)
signal shield_broken

@export_range(1.0, 1000.0, 1.0, "or_greater")
var maximum: float = 100.0

var current: float
var shield_maximum: float = 0.0
var shield_current: float = 0.0


func _ready() -> void:
	current = maximum
	shield_current = shield_maximum


func take_damage(amount: float) -> float:
	if amount <= 0.0 or is_depleted():
		return 0.0

	var remaining_damage := amount

	if shield_current > 0.0:
		var previous_shield := shield_current
		shield_current = maxf(shield_current - remaining_damage, 0.0)

		var absorbed := previous_shield - shield_current
		remaining_damage -= absorbed

		shield_changed.emit(shield_current, shield_maximum)

		if shield_current <= 0.0:
			shield_broken.emit()

	if remaining_damage <= 0.0:
		return amount

	var previous := current
	current = maxf(current - remaining_damage, 0.0)
	var applied_damage := previous - current

	damaged.emit(applied_damage)
	changed.emit(current, maximum)

	if is_depleted():
		depleted.emit()

	return applied_damage


func is_depleted() -> bool:
	return current <= 0.0


func set_shield_maximum(new_max: float) -> void:
	shield_maximum = maxf(new_max, 0.0)
	shield_current = minf(shield_current, shield_maximum)
	shield_changed.emit(shield_current, shield_maximum)


func reset() -> void:
	current = maximum
	shield_current = shield_maximum
	changed.emit(current, maximum)
	shield_changed.emit(shield_current, shield_maximum)
