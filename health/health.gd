class_name Health
extends Node

signal changed(current: float, maximum: float)
signal damaged(amount: float)
signal depleted

@export_range(1.0, 1000.0, 1.0, "or_greater")
var maximum: float = 100.0 

var current: float


func _ready() -> void:
    current = maximum


func take_damage(amount: float) -> float:
    if amount <= 0.0 or is_depleted():
        return 0.0

    var previous := current

    current = maxf(current - amount, 0.0)

    var applied_damage := previous - current

    damaged.emit(applied_damage)
    changed.emit(current, maximum)

    if is_depleted():
        depleted.emit()

    return applied_damage


func is_depleted() -> bool:
    return current <= 0.0