# This is a resource that defines a spell in the game. 
# It contains all the necessary information about the spell, such as its name, description, cooldown, and command scene.

class_name SpellDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var cooldown: float

# TODO: Check if this is the best way to handle the sequence of spell effects. 
@export var sequence: Array[StringName] = []
@export var command_scene: PackedScene

# TODO: This is a placeholder for the spell icon. We need to decide how to handle icons for spells in the future.
# @export var icon: Texture2D