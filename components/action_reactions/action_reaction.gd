class_name ActionReaction
extends Node


func supports(_action: ActionData) -> bool:
    return false


func react(_action: ActionData) -> void:
    push_error("ActionReaction: react() method must be implemented in subclasses.")