class_name ActionReceiver
extends Area2D

signal action_received(action: ActionData)
signal action_ignored(action: ActionData)


func receive_action(action: ActionData) -> void:
    var handled := false

    print("ActionReceiver: Received action of type '%s' from source '%s'" % [action.type, action.source])

    # Maybe we can use a more efficient way to get the children that are ActionReaction, but for now this is fine.
    for child in get_children():
        var reaction := child as ActionReaction

        if reaction == null:
            continue

        if not reaction.supports(action):
            continue
        
        reaction.react(action)
        handled = true
    
    if handled:
        action_received.emit(action)
    else:
        action_ignored.emit(action)
    
            