# This is a resource that defines a spell in the game. 
# It contains all the necessary information about the spell, such as its name, description, cooldown, and command scene.

class_name SpellDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export_range(0.0, 3600.0, 0.05, "or_greater") var cooldown: float = 0.0

# TODO: Check if this is the best way to handle the sequence of spell effects. 
@export var sequence: Array[StringName] = []
@export var command_scene: PackedScene
