# This class is used to store the context of a spell, including the caster, target, and any other relevant information.

class_name SpellContext
extends RefCounted

var caster: Node2D
var effect_parent: Node

var origin: Vector2
var direction: Vector2
var target_position: Vector2

var metadata: Dictionary = {}

# This may include additional information about the player, such as their level, stats, 
# or any other relevant data that may affect the spell's behavior.