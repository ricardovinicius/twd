class_name Equipment
extends Node

signal equipment_changed(slot_index: int, item: ItemDefinition)

const SLOT_COUNT := 3

var _slots: Array[ItemDefinition] = [null, null, null]

@export var stats: PlayerStats
@export var health: Health
@export var horizontal_movement: HorizontalMovementComponent


func _ready() -> void:
	if stats == null or health == null or horizontal_movement == null:
		push_error("Equipment: Stats, Health, and HorizontalMovement must be assigned.")
		return
	_apply_totals()


func equip(slot_index: int, item: ItemDefinition) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		push_error("Invalid equipment slot: %d" % slot_index)
		return false

	if stats == null or health == null or horizontal_movement == null:
		return false
	if _slots[slot_index] == item:
		return false

	_slots[slot_index] = item
	_apply_totals()
	equipment_changed.emit(slot_index, item)
	return true


func unequip(slot_index: int) -> void:
	equip(slot_index, null)


func get_item(slot_index: int) -> ItemDefinition:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return null
	return _slots[slot_index]


func get_total_bonus() -> Dictionary:
	var totals := {
		"weight": 0.0,
		"weight_multiplier": 1.0,
		"shield": 0.0,
		"resistance_arc": 0.0,
		"resistance_san": 0.0,
		"resistance_col": 0.0,
		"resistance_fle": 0.0,
		"resistance_mel": 0.0,
		"move_speed": 0.0,
		"insight": 0,
	}

	for item in _slots:
		if item == null:
			continue

		totals.weight += item.bonus_weight
		totals.weight_multiplier *= item.weight_multiplier
		totals.shield += item.bonus_shield
		totals.resistance_arc += item.bonus_resistance_arc
		totals.resistance_san += item.bonus_resistance_san
		totals.resistance_col += item.bonus_resistance_col
		totals.resistance_fle += item.bonus_resistance_fle
		totals.resistance_mel += item.bonus_resistance_mel
		totals.move_speed += item.bonus_move_speed
		totals.insight += item.bonus_insight

	return totals


func get_final_weight() -> float:
	var totals := get_total_bonus()
	return (stats.base_weight + totals.weight) * totals.weight_multiplier


func _apply_totals() -> void:
	var totals := get_total_bonus()

	health.set_shield_maximum(stats.base_shield_maximum + totals.shield)
	horizontal_movement.max_speed = stats.base_move_speed + totals.move_speed
	# weight, resistance_* e insight ficam disponíveis via get_total_bonus()
	# para a UI ler diretamente — não afetam nenhum sistema físico ainda.
