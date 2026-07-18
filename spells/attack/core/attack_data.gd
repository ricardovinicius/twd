class_name AttackData
extends RefCounted

var attack_type: StringName = &""
var source: Node2D
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var damage: float = 0.0

# We must add other properties as needed, such as lifetime, speed, etc. For now, we will keep it simple.
