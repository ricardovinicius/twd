class_name Equipment
extends Node

signal equipment_changed(slot_index: int, item: ItemDefinition)

const SLOT_COUNT := 3

var slots: Array[ItemDefinition] = [null, null, null]

@onready var player: CharacterBody2D = get_parent()
@onready var stats: PlayerStats = player.get_node("Stats")
@onready var health: Health = player.get_node("Health")
@onready var horizontal_movement: HorizontalMovementComponent = player.get_node("HorizontalMovement")


func _ready() -> void:
	slots.resize(SLOT_COUNT)
	_apply_totals()


func equip(slot_index: int, item: ItemDefinition) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		push_error("Invalid equipment slot: %d" % slot_index)
		return false

	slots[slot_index] = item
	_apply_totals()
	equipment_changed.emit(slot_index, item)
	return true


func unequip(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return

	slots[slot_index] = null
	_apply_totals()
	equipment_changed.emit(slot_index, null)


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

	for item in slots:
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
