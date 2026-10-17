class_name RigidBodyPushReaction
extends ActionReaction

@export var body: RigidBody2D
@export_range(0.1, 100.0) var resistance: float = 1.0
## Velocidade máxima que um empurrão pode dar ao corpo. Evita que objetos leves
## sejam arremessados para fora do mapa.
@export var max_push_speed: float = 900.0


func supports(action: ActionData) -> bool:
    return action.type == &"push"


func react(action: ActionData) -> void:
    if body == null:
        push_warning("RigidBodyPushReaction: body is null.")
        return

    var force_vector = action.direction * action.strength / resistance
    var max_impulse := max_push_speed * body.mass
    force_vector = force_vector.limit_length(max_impulse)
    body.apply_central_impulse(force_vector)