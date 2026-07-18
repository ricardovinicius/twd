class_name AttackReceiver
extends Area2D

signal attack_received(attack: AttackData)
signal attack_ignored(attack: AttackData)


func receive_attack(attack: AttackData) -> void:    
    if attack == null:
        push_warning("AttackReceiver: Received a null attack.")
        attack_ignored.emit(attack)
        return

    var handled := false

    print("AttackReceiver: Received attack of type '%s' from source '%s'" % [attack.attack_type, attack.source])

    for child in get_children():
        var reaction := child as AttackReaction

        if reaction == null:
            continue

        if not reaction.supports(attack):
            continue
        
        reaction.react(attack)
        handled = true
    
    if handled:
        attack_received.emit(attack)
    else:
        attack_ignored.emit(attack)