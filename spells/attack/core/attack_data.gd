class_name AttackData
extends RefCounted

var attack_type: StringName = &""
var source: Node2D
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var damage: float = 0.0
## Kind of damage, such as &"physical" or &"fire". Reactions may use it.
var damage_type: StringName = &"physical"
## Extra effects carried by the attack, such as a BurnEffect. Reactions that
## do not know an effect ignore it.
var effects: Array[RefCounted] = []

# We must add other properties as needed, such as lifetime, speed, etc. For now, we will keep it simple.
