class_name EquipmentPanel
extends PanelContainer

@export var equipment: Equipment
@export var stats: PlayerStats
@export var health: Health
@export var inventory: Inventory

@onready var slot_buttons: Array[Button] = [%Slot0, %Slot1, %Slot2]

@onready var weight_label: Label = %WeightLabel
@onready var shield_label: Label = %ShieldLabel
@onready var resistance_arc_label: Label = %ResistanceArcLabel
@onready var resistance_san_label: Label = %ResistanceSanLabel
@onready var resistance_col_label: Label = %ResistanceColLabel
@onready var resistance_fle_label: Label = %ResistanceFleLabel
@onready var resistance_mel_label: Label = %ResistanceMelLabel
@onready var move_speed_label: Label = %MoveSpeedLabel
@onready var insight_label: Label = %InsightLabel

signal slot_pressed(slot_index: int)


func _ready() -> void:
	for i in slot_buttons.size():
		slot_buttons[i].pressed.connect(_on_slot_pressed.bind(i))


func refresh() -> void:
	if not equipment.equipment_changed.is_connected(_on_equipment_changed):
		equipment.equipment_changed.connect(_on_equipment_changed)

	_refresh_slots()
	_refresh_status()


func _on_slot_pressed(slot_index: int) -> void:
	slot_pressed.emit(slot_index)


func _on_equipment_changed(_slot_index: int, _item: ItemDefinition) -> void:
	refresh()


func _refresh_slots() -> void:
	for i in slot_buttons.size():
		var item := equipment.slots[i]
		slot_buttons[i].text = item.display_name if item != null else "Item"
		slot_buttons[i].icon = item.icon if item != null else null


func _refresh_status() -> void:
	var totals := equipment.get_total_bonus()

	weight_label.text = "PESO: %s" % _format_bonus(stats.base_weight + totals.weight)
	shield_label.text = "SHIELD: %.0f/%.0f" % [health.shield_current, health.shield_maximum]
	resistance_arc_label.text = "Res. ARC: %s" % _format_bonus(stats.base_resistance_arc + totals.resistance_arc)
	resistance_san_label.text = "Res. SAN: %s" % _format_bonus(stats.base_resistance_san + totals.resistance_san)
	resistance_col_label.text = "Res. COL: %s" % _format_bonus(stats.base_resistance_col + totals.resistance_col)
	resistance_fle_label.text = "Res. FLE: %s" % _format_bonus(stats.base_resistance_fle + totals.resistance_fle)
	resistance_mel_label.text = "Res. MEL: %s" % _format_bonus(stats.base_resistance_mel + totals.resistance_mel)
	move_speed_label.text = "MOVESPEED: %s" % _format_bonus(stats.base_move_speed + totals.move_speed)
	insight_label.text = "INSIGHT: %d" % (stats.base_insight + totals.insight)


func _format_bonus(value: float) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%s" % [prefix, str(value)]
