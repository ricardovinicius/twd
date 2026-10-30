# 026 — Star Man

## Overview

A man with a star stuck around his neck. He stands still until he sees the player, screams, then curls up into the star and rolls at the player like a madman. He cannot be hurt while rolling; when the roll ends he stands dizzy and only then can he be damaged. Placeholder art is very low fidelity (32×32 frames, scaled 3×) and will be replaced.

## Behavior rules

1. **Idle.** He stands still until he sees a player: inside `Vision` (`vision_radius`, 420) with a clear ray on `line_of_sight_mask`. Walls hide the player.
2. **Scream.** On first sight he faces the player and screams for `scream_duration` (0.9 s), standing still, and emits `screamed(target)`.
3. **Roll.** He rolls toward the player for `roll_duration` (2.4 s), accelerating to `roll_speed` (620, faster than the player). While rolling he:
   - hops at random intervals (`hop_interval`, `hop_speed`);
   - turns back after rolling `overshoot_distance` (180) past the player, at most `max_turns` (2) times per roll;
   - bounces off walls in the other direction;
   - spins the sprite with the distance travelled;
   - deals `roll_contact_damage` (20) with `roll_knockback` on contact.
4. **Invulnerable roll.** While rolling, `StarGuardReaction` deflects every attack: health is untouched, `deflected(attack)` is emitted, and the sprite flashes. Projectiles still stop on him.
5. **Dizzy.** When the roll ends he brakes to a stop and stands dizzy for `dizzy_duration` (1.8 s). He takes damage normally, and contact damage drops to `stand_contact_damage` (5).
6. **Again.** After the daze he rolls again (no scream) while the target is within `lose_radius` (1000); otherwise he forgets the player and goes idle, screaming again on the next sighting.
7. **Vulnerability.** He can be hurt whenever he is not rolling (idle, screaming, dizzy).
8. **Death.** 120 HP; drops 4 × 20 Stardust.
9. `rng_seed` makes the hops repeatable (0 = random).

## Scene composition

```text
StarMan (CharacterBody2D, StarMan, scale 3, layer Entities, mask World + One-way)
├── AnimatedSprite2D   idle (2), scream (2), roll (1, rotated in code), dizzy (3), hit (1)
├── CollisionShape2D
├── Gravity
├── Vision             TargetDetector (radius = vision_radius)
├── ContactImpact      damage/knockback switched per state
├── Health             120
├── DestroyOnDeath
├── StardustDropOnDeath 4 × 20
└── AttackReceiver
    └── StarGuardReaction
```

He is on the Entities layer (the player bumps into him) but does not collide with the player himself, so his roll passes through and knocks the player away.

## Public contracts

- `StarMan`: `get_state()`, `get_target()`, `get_roll_direction()`, `is_vulnerable()`, `has_line_of_sight(point)`, `can_see(target)`; signals `state_changed(state)`, `screamed(target)`.
- `StarGuardReaction`: `guarded`, signal `deflected(attack)`.

## Art replacement

Sprites in `entities/enemies/star_man/sprites/`, 32×32 frames facing right:

| File | Frames | Use |
| --- | --- | --- |
| `idle_32x32.png` | 2 | Standing, star around the neck. |
| `scream_32x32.png` | 2 | Screaming, mouth open. |
| `roll_32x32.png` | 1 | Curled into the star, centred; the code spins it. |
| `dizzy_32x32.png` | 3 | Standing dizzy after a roll. |
| `hit_32x32.png` | 1 | Shown briefly when damaged. |

## Scope limits

- He is a regular (tough) enemy, not a boss: `EnemyRespawner` recreates him when the player dies or rests, like the other enemies. There is no boss fight structure (arena, boss health bar) yet.

## Acceptance criteria

- Hidden by walls; screams once on sight, standing still; then rolls toward the player at full speed, spinning.
- Attacks are deflected while rolling and land while he stands.
- He turns back after overshooting (bounded), bounces off walls, gets dizzy after the roll, and rolls again while the player is near.
- He forgets a far player; death drops Stardust; respawn and monster guide entry work.

## Testing

`tests/star_man/`. Manually verify the madness of the roll, readability of the dizzy window, and contact knockback in a level.
