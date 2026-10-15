extends Node2D

@export var pause_menu: PauseMenu
@export var spell_registry: SpellRegistry
@export var equipment: Equipment
@export var stats: PlayerStats
@export var health: Health
@export var inventory: Inventory


func _ready() -> void:
	if pause_menu == null:
		push_error("Main: PauseMenu is not assigned.")
		return
	pause_menu.setup(spell_registry, equipment, stats, health, inventory)
