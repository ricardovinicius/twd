# 024 — Homunculus Couple

## Overview

Two homunculi in love stand on the ground, kissing, with a heart floating above them. When the player comes into view they keep kissing but turn their eyes to the player; a moment later they break apart and both run after the player, fast. They do not give up while they are on the player's screen. Once the player leaves them off screen, they walk back to their spots and kiss again. Placeholder art is deliberately very low fidelity (16×16 frames, scaled 3×) and will be replaced by hand-drawn sprites.

## Goals

- A grounded enemy pair that starts passive and turns into two fast chasers.
- Coordination lives in one couple scene; each homunculus is a self-contained enemy (movement, contact damage, health, drops).
- Art that can be swapped without touching code.

## Behavior rules

1. **Kissing.** Both homunculi stand still, facing each other, playing `kiss`. The heart is visible only in this state.
2. **Sight.** The couple sees a player inside its `Vision` circle (`vision_radius`) with a clear ray from the couple's origin on `line_of_sight_mask` (World by default). Walls block sight.
3. **Stare.** Seeing the player while kissing starts the stare: both stay in place with lips together (heart still visible) and look at the player for `stare_duration` (0.6 s). Each one plays `stare_front` when the player is on the side it faces and `stare_back` when the player is behind it, updated every frame.
4. **Damage skips the stare.** Damage to either homunculus starts the chase at once, toward the attacker when it belongs to `target_group`, otherwise the closest visible player. Damage is always applied normally.
5. **Chase.** After the stare, each homunculus runs toward the target's x position at `max_speed` (360, faster than the skeleton and slightly slower than the player). The heart disappears. The two never collide with each other.
6. **Contact.** Touching a homunculus deals 15 damage and knockback through `ContactImpactComponent`.
7. **Never giving up on screen.** Sight no longer matters once they chase. They give up only when the target is gone, or when both homunculi have been outside the visible screen (the viewport's canvas area, grown by `screen_margin`) for `offscreen_grace` (0.75 s). Then both walk back to their own spots. Seeing the player on the way makes them chase again (no stare).
8. **Making up.** When both are home and on the floor, they face each other and kiss again.
9. **Death.** Each homunculus has 30 HP and drops 1 × 10 Stardust. A lone survivor stops kissing (it waits, then chases and returns on its own). The couple node frees itself once both are dead.
10. **Respawn.** The couple is placed under `EnemyRespawner` like other enemies; homes are read on the first physics frame, after placement.

## Scene composition

```text
HomunculusCouple (Node2D, HomunculusCouple)
├── Left    Homunculus.tscn at (-21, 0)
├── Right   Homunculus.tscn at (21, 0)
├── Heart   AnimatedSprite2D, 2-frame pulse, scale 3
└── Vision  TargetDetector (mask Entities) + CircleShape2D

Homunculus (CharacterBody2D, Homunculus, scale 3, layer Entities, mask World + One-way + Entities)
├── AnimatedSprite2D    kiss, alert, run, hit
├── CollisionShape2D
├── HorizontalMovement  max 360, acceleration 1400
├── Gravity
├── ContactImpact       15 damage + ContactArea
├── Health              30 HP
├── DestroyOnDeath
├── StardustDropOnDeath 1 × 10
└── AttackReceiver      + HealthDamageReaction
```

## Component responsibilities

| Component | Responsibility |
| --- | --- |
| `HomunculusCouple` | Sight, stare timing, on-screen chase limit, returning, re-kissing, heart visibility, freeing the empty couple. |
| `Homunculus` | Its own movement modes (kiss, stare, chase, return, idle), facing, gravity, and animation. |
| Shared enemy components | Detection, contact damage, health, receivers, death, and drops, as on the other enemies. |

## Public contracts

- `HomunculusCouple`: `get_state()`, `get_target()`, `get_home()`, `has_line_of_sight(point)`, `can_see(target)`, `is_on_screen(node)`, `is_any_member_on_screen()`; signal `state_changed(state)`.
- `Homunculus`: `kiss(facing)`, `stare(target)`, `chase(target)`, `return_home(home_x)`, `wait()`, `is_home()`, `is_looking_back()`, `get_state()`, `get_target()`, `get_facing()`; signal `state_changed(state)`.

## Failure handling

- A target that is freed or leaves the tree ends the chase. Sight also checks distance, so a stale detector overlap after a teleport is ignored.
- A target lost during the stare sends them home instead of chasing.
- Damage with no attacker in the target group and no visible player is applied without waking the couple.
- Removed members are skipped everywhere; the couple never orders a freed homunculus.

## Art replacement

Sprites live in `entities/enemies/homunculus_couple/sprites/`. Each animation is a horizontal strip of 16×16 frames, drawn **facing right** (the code flips them). Keep the file names, or update the atlas regions in `Homunculus.tscn` if the frame size or count changes.

| File | Frames | Use |
| --- | --- | --- |
| `kiss_16x16.png` | 2 (loop, 3 fps) | Eyes closed, lips on the right edge so the pair meets in the middle. |
| `stare_16x16.png` | 2 | Frame 0 `stare_front`: mid-kiss, eyes open looking ahead. Frame 1 `stare_back`: mid-kiss, looking back over the shoulder. Lips stay on the right edge. |
| `alert_16x16.png` | 1 | The lone survivor's idle pose. |
| `run_16x16.png` | 4 (loop, 12 fps) | Angry run. |
| `hit_16x16.png` | 1 | Shown for `hit_duration` after damage. |
| `heart_7x6.png` | 2 (loop, 3 fps) | Heart above the kiss. |
| `portrait.png` | 1 | Monster guide portrait (the kissing pair). |

Larger frames work: change the atlas regions and adjust the collision shapes and the `Left`/`Right` offsets so the lips still touch.

## Scope limits

- No jumping or pathfinding: they run along the ground and stop at walls or fall off ledges.
- No separate attack animation; damage comes from contact.

## Acceptance criteria

- The couple starts kissing in place with a visible heart.
- A player in sight makes them stare at the player mid-kiss (front or back pose by side), then both chase at top speed and the heart disappears.
- They keep chasing a player outside their vision while they are on screen.
- Leaving them off screen for `offscreen_grace` sends them home, where they kiss again.
- A wall between them and the player keeps them kissing.
- Damaging either one starts the chase at once toward the attacker.
- Each death drops one 10-Stardust pickup; the couple is freed when both are dead; a survivor stops kissing.
- The respawner recreates the couple with its configuration; the monster guide lists it.

## Testing

`tests/homunculus_couple/` covers all acceptance criteria. Manually verify the stare, the chase feel against the real camera, and replacement art alignment in a level.
