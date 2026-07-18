class_name HealthDamageReaction
extends AttackReaction

@export var health: Health


func _ready() -> void:
    # Guard Rails
    assert(health != null, "HealthDamageReaction: Health is not assigned.")


func supports(_attack: AttackData) -> bool:
    return (
        _attack != null
        and _attack.damage > 0.0
        and not health.is_depleted()
    )


func react(_attack: AttackData) -> void:
    health.take_damage(_attack.damage)