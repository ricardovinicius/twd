class_name MagicArrowSpell
extends SpellCommand

@export var projectile_scene: PackedScene

@export_range(0.0, 10000.0, 1.0, "or_greater")
var speed: float = 500.0

@export_range(0.0, 10000.0, 1.0, "or_greater")
var lifetime: float = 5.0

@export_range(0.0, 10000.0, 1.0, "or_greater")
var damage: float = 10.0


func _execute() -> void:
    if context == null:
        fail(&"missing_context")
        return
    
    if context.caster == null:
        fail(&"missing_caster")
        return

    if context.direction.is_zero_approx():
        fail(&"missing_direction")
        return
    
    if projectile_scene == null:
        fail(&"missing_projectile_scene")
        return
    
    var instance := projectile_scene.instantiate()
    var projectile := instance as MagicArrowProjectile

    if projectile == null:
        instance.queue_free()
        fail(&"invalid_projectile_scene")
        return
    
    var attack := _create_attack_data()
    var projectile_parent := _get_projectile_parent()

    # FIX: The projectile should not be child of the caster, as it may cause issues with collision detection and other behaviors. 
    # Instead, it should be added to a neutral parent node in the scene tree.
    projectile_parent.add_child(projectile)

    projectile.launch(
        context.origin,
        context.direction.normalized(),
        attack,
        speed,
        lifetime
    )

    complete()


func _create_attack_data() -> AttackData:
    var attack := AttackData.new()

    attack.attack_type = &"magic_arrow"
    attack.source = context.caster
    attack.origin = context.origin
    attack.direction = context.direction.normalized()
    attack.damage = damage

    return attack


func _get_projectile_parent() -> Node:
    if context.effect_parent != null:
        return context.effect_parent
    
    return get_parent()


