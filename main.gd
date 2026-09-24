extends Node2D

@onready var player: CharacterBody2D = $LevelRoot/Player
@onready var pause_menu: PauseMenu = $PauseMenuLayer/PauseMenu


func _ready() -> void:
	print("MAIN READY - player: ", player, " pause_menu: ", pause_menu)
	pause_menu.equipment_panel.equipment = player.get_node("Equipment")
	pause_menu.equipment_panel.stats = player.get_node("Stats")
	pause_menu.equipment_panel.health = player.get_node("Health")
	pause_menu.equipment_panel.inventory = player.get_node("Inventory")
	print("EQUIPMENT ATRIBUIDO: ", pause_menu.equipment_panel.equipment)
