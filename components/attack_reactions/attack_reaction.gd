class_name AttackReaction
extends Node


func supports(_attack: AttackData) -> bool:
    return false


func react(_attack: AttackData) -> void:
    push_error("AttackReaction: react() method must be implemented on the subclasses.")