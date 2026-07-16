class_name RigidBodyPushReaction
extends ActionReaction

@export var body: RigidBody2D
@export_range(0.1, 100.0) var resistance: float = 1.0


func supports(action: ActionData) -> bool:
    return action.type == &"push"


func react(action: ActionData) -> void:
    if body == null:
        push_warning("RigidBodyPushReaction: body is null.")
        return

    var force_vector = action.direction * action.strength / resistance
    print("RigidBodyPushReaction: Applying force vector %s to body %s" % [force_vector, body])
    body.apply_central_impulse(force_vector)