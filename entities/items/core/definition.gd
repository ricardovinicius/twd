class_name ItemDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D

@export_category("Bonuses")
@export var bonus_weight: float = 0.0
@export var bonus_shield: float = 0.0
@export var bonus_resistance_arc: float = 0.0
@export var bonus_resistance_san: float = 0.0
@export var bonus_resistance_col: float = 0.0
@export var bonus_resistance_fle: float = 0.0
@export var bonus_resistance_mel: float = 0.0
@export var bonus_move_speed: float = 0.0
@export var bonus_insight: int = 0

@export_category("Multipliers")
@export var weight_multiplier: float = 1.0
