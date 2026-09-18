class_name Inventory
extends Node

signal item_added(item: ItemDefinition, new_quantity: int)

var _quantities: Dictionary = {}  # ItemDefinition -> int


func add_item(item: ItemDefinition, amount: int = 1) -> void:
	var current: int = _quantities.get(item, 0)
	_quantities[item] = current + amount
	item_added.emit(item, _quantities[item])


func get_quantity(item: ItemDefinition) -> int:
	return _quantities.get(item, 0)


func has_item(item_id: StringName) -> bool:
	for item: ItemDefinition in _quantities:
		if item.id == item_id and _quantities[item] > 0:
			return true
	return false


func get_items() -> Dictionary:
	return _quantities.duplicate()
