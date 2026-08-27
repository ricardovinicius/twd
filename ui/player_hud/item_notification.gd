extends Control

@onready var label: Label = $Label
@onready var icon_rect: TextureRect = $TextureRect


func _ready() -> void:
	Events.item_collected.connect(_on_item_collected)
	modulate.a = 0.0


func _on_item_collected(item: ItemDefinition, new_quantity: int) -> void:
	label.text = "%s x%d" % [item.display_name, new_quantity]
	icon_rect.texture = item.icon

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
