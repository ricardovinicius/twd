#player HUD
extends CanvasLayer

@onready var hp_margin_container: MarginContainer = %HPMarginContainer
@onready var hp_bar: TextureProgressBar = %hp_bar


func _ready() -> void:
	
	pass



func update_health_bar( hp: float, max_hp: float ) -> void:
	var value : float = ( hp / max_hp ) * 100
	hp_bar.value = value
	hp_margin_container.size.x = max_hp + 3
	pass
