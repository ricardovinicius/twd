# Feature Overview

A grimoire (spellbook) floats beside the player as a companion. It follows her with smoothed movement, bobs gently in the air, and passes through level geometry to reach her. It has no gameplay effect yet. Its art is a low-fidelity placeholder about the player's size: a 32×32 px book drawn with polygons at the player's scale (3×).

## Goals

- Give the player a visible companion that reads as a magic book.
- Keep follow movement and presentation in focused components inside the companion's own feature.
- Compose it into the level with an explicit target reference, without tree searches.

## Non-Goals

- Gameplay abilities, dialogue, or spell casting from the grimoire.
- Pathfinding or collision; the grimoire intentionally ignores walls.
- Final art, animation frames, particles, or sound.
- Saving companion state.

# Behavior Rules

- The grimoire heads for a spot beside its target: `follow_offset` (default `(-72, -90)` px, behind and above the player) while the target moves right; the horizontal offset mirrors when the target moves left, so it stays behind her.
- The side switches only when the target moves horizontally faster than `turn_speed_threshold` (default `20` px/s); standing still keeps the current side.
- Each physics tick it moves `1 - exp(-follow_speed * delta)` of the remaining distance (default `follow_speed = 4`), capped at `max_speed` (default `1400` px/s). Movement is frame-rate independent and runs in physics so physics interpolation smooths it.
- It has no collision objects, so walls, floors, and one-way platforms never stop it.
- It starts at its spot beside the target. If the spot is farther than `snap_distance` (default `1500` px), such as after a respawn or load teleport, it snaps there and resets physics interpolation instead of flying across the map.
- If the target is freed, it stays where it is.
- `HoverBobComponent` bobs and sways only the `Sprite` node (default `6` px, `1.6` s period, `4°`); it never changes the grimoire's position.
- In Level 01 the grimoire comes before `Player` in the tree, so it is drawn behind her and in front of earlier level nodes such as tiles.

# Scene Composition

`entities/companions/grimoire/Grimoire.tscn`:

```text
Grimoire (Node2D)
├── Sprite (Node2D, scale 3)          placeholder art, 28×28 px inside a 32×32 box
│   ├── Spine, Cover, Pages, Strap, Emblem, EmblemEye (Polygon2D)
├── CompanionFollow (CompanionFollowComponent)   body -> .., target set by the level
└── HoverBob (HoverBobComponent)                 visual -> ../Sprite
```

Level 01 (`levels/level_01/Level01.tscn`):

```text
Level01
├── ... ElevatorC
├── Grimoire                     instance, CompanionFollow.target -> ../../Player
└── Player
```

| Component | Responsibility |
| --- | --- |
| `CompanionFollowComponent` | Follow destination, side switching, smoothing, speed cap, snapping, and missing-target safety. Moves its `body`; independent of the player script. |
| `HoverBobComponent` | Presentation-only bob and sway of a visual node. |
| `Grimoire.tscn` | Composes the placeholder art and both components; no root script. |
| Level 01 | Places the grimoire and wires its target explicitly. |

# Public Contracts

```gdscript
class_name CompanionFollowComponent
extends Node

signal snapped_to_target

@export var body: Node2D
@export var target: Node2D
@export var follow_offset: Vector2 = Vector2(-72.0, -90.0)
@export var follow_speed: float = 4.0
@export var max_speed: float = 1400.0
@export var turn_speed_threshold: float = 20.0
@export var snap_distance: float = 1500.0

func get_destination() -> Vector2
func snap_to_target() -> void
```

```gdscript
class_name HoverBobComponent
extends Node

@export var visual: Node2D
@export var bob_height: float = 6.0
@export var bob_period: float = 1.6
@export var sway_degrees: float = 4.0
```

Replacing the art: delete the `Polygon2D` children of `Sprite` and add a `Sprite2D` (32×32 texture, nearest filter) under it; the scale and components stay the same.

# Failure Handling

- Missing `body` or `target` is reported with `push_error` and the component stays idle.
- Missing `visual` is reported with `push_error` and the bob stays idle.
- A freed target leaves the grimoire in place without errors.

# Implementation Plan

1. Create `entities/companions/grimoire/` with both components and `Grimoire.tscn`.
2. Instance it in Level 01 before `Player` and wire `CompanionFollow.target`.
3. Add the `grimoire` test suite.
4. Manually check the follow feel, side switching, drawing order, and the look at 3× scale in game.

# Testing

`tests/grimoire/`:

- Scene composition: components wired, sprite at scale 3, art within 32×32 and at least 24×24, no collision objects.
- Starts beside the target; closes in monotonically and smoothly (step ≤ speed cap) and arrives.
- Reaches a target on the other side of a wall.
- Switches and mirrors sides with the target's direction.
- Snaps after a far teleport; stays put when the target is freed.
- Level 01 composes it before `Player` with `target` set to `Player`.

# Acceptance Criteria

1. A book about the player's size floats behind the player in Level 01.
2. It follows smoothly, without jitter, and catches up through walls and floors.
3. It switches sides when the player turns around.
4. After a respawn far away it appears beside the player instead of flying across the level.
