class_name ActionData
extends RefCounted

var type: StringName
var source: Node2D
var origin: Vector2
var direction: Vector2
var strength: float
var metadata: Dictionary = {}


func duplicate_action() -> ActionData:
    var new_action = ActionData.new()

    new_action.type = type
    new_action.source = source
    new_action.origin = origin
    new_action.direction = direction
    new_action.strength = strength
    new_action.metadata = metadata.duplicate(true)

    return new_action

