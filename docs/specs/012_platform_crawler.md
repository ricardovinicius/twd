# Feature Overview

Add a **Platform Crawler** enemy that sweeps one floating platform by crawling around its whole perimeter in a continuous loop: along the top, down one side, upside down along the bottom, and up the other side. It always stays attached to its platform.

The crawler sees only what is in front of it and in its line of sight. When the player enters its vision radius **in front of it** with nothing solid in between, the crawler speeds up along its path to run into the player. A player behind the crawler, or on the other side of its platform, is not detected. The crawler never passes through the player: each hit makes it back off and charge again, so it attacks repeatedly. It can be killed through the normal attack pipeline and drops Stardust like the Basic Skeleton.

The first placements are the two isolated 4×2-tile platforms in the left room of Level 01.

## Goals

- Add a second enemy type with a readable, predictable patrol.
- Keep perimeter movement, vision, contact damage, health, and death behavior in focused composed components.
- Configure the platform shape and speeds per placement in the level.
- Reuse the existing contact-impact, attack-receiver, health, death, and Stardust-drop components.

## Non-Goals

- Final art, animation, or sound. The crawler uses a simple placeholder shape.
- Detecting the platform automatically from the tilemap.
- Leaving the platform, jumping, or chasing the player across the level.
- Reversing direction to follow a player behind it.
- Non-rectangular platforms.

# Behavior Rules

## Perimeter Movement

- The crawler's scene root is placed at the centre of its platform's collision rectangle. `platform_size` is that rectangle's size in pixels.
- The crawler's body follows a rounded rectangle around the platform, offset by `clearance` (half of the body's height), so its underside stays on the platform surface. Corners are quarter circles of radius `clearance`.
- The body rotates so its "up" always points away from the surface: upright on top, sideways on the walls, upside down on the bottom.
- `direction` is `1` (clockwise on screen: right along the top) or `-1` (counter-clockwise). `start_distance` sets where on the loop it starts, measured clockwise from the top-left end of the top edge.
- Movement loops forever. The crawler ignores gravity and physics pushes.

## Vision

- The crawler has a circular vision area of `vision_radius` around its body.
- A body in the `player` group inside that area is **in front** when the angle between the crawler's forward direction (its direction of travel) and the direction to the player is less than `vision_half_angle` (default `90°`, the whole front half).
- The player must also be in **line of sight**: a ray from the crawler's body to the player must not hit anything on `line_of_sight_mask` (default layer 1, the level's solid tiles). A player on the other side of the crawler's own platform, or behind a wall, is not detected.
- A player behind the crawler, or exactly perpendicular to it, is not detected.
- Because the crawler rotates around the platform, "front" follows its travel direction on every side.

## Speeds

- **Patrol:** with no player in front, the crawler moves at `patrol_speed` (default `90` px/s).
- **Charge:** with a player in front, it moves at `charge_speed` (default `280` px/s) in the same direction. It never turns around.
- Speed changes toward the target speed at `acceleration` (default `700` px/s²), so speeding up and slowing down are visible.
- When the player leaves the vision area, moves behind it, or goes out of sight, the crawler returns to patrol speed.
- The placeholder is tinted `charge_color` while charging or recoiling and `patrol_color` while patrolling.

## Attack Cycle

The crawler attacks by running into the player and never passes through them.

1. **Hit:** when `ContactImpactComponent` applies contact to the player, or when the player overlaps the contact area in front of the crawler (for example, while the contact cooldown is active), the crawler enters **Recoil**.
2. **Recoil:** it moves backward along its loop by `recoil_distance` (default `48` px) over `recoil_duration` (default `0.2` s).
3. **Pause:** it stays still for `attack_pause` (default `0.25` s).
4. **Resume:** it returns to Patrol from a standstill. If the player is still visible in front, it charges again and accelerates into the next hit.

- Recoil cannot restart while it is already recoiling.
- Vision is not evaluated during Recoil and Pause.
- A player standing still in front is therefore hit repeatedly, once per cycle, subject to the contact cooldown.

## Combat and Death

- Contact with the player applies `ContactImpactComponent` damage and knockback with its usual per-target cooldown, then starts the attack cycle.
- Attacks reach the crawler through `AttackReceiver` → `HealthDamageReaction` → `Health`.
- On death, `DestroyOnDeath` frees the crawler and `StardustDropOnDeath` drops 2 × 10 Stardust at the body's position.
- The crawler does not block the player's movement. It is not a solid physics body.

## Respawn

- Crawlers are children of the level's `EnemyRespawner` and are recreated when the player dies, like other enemies.
- `EnemyRespawner` restores each enemy's exported, non-object property values (such as `platform_size`, speeds, and `direction`) when it recreates it, so per-placement configuration survives a respawn.

# Implementation Details

## Composition

```text
PlatformCrawler (Node2D, at the platform centre)
├── Movement (PerimeterMovementComponent)
├── Body (Node2D, moved and rotated along the perimeter)
│   ├── Visual (Node2D, flipped by direction)
│   │   ├── Shell (Polygon2D)
│   │   └── Eye (Polygon2D, marks the front)
│   ├── Vision (Area2D, TargetDetector)
│   ├── ContactImpact (ContactImpactComponent)
│   │   └── ContactArea (Area2D)
│   └── AttackReceiver (Area2D)
│       └── HealthDamageReaction
├── Health
├── DestroyOnDeath
└── StardustDropOnDeath
```

| Component | Responsibility |
| --- | --- |
| `PlatformCrawler` | Pick patrol or charge from the visible targets in front, run the recoil/pause attack cycle, ramp its speed, advance the movement, and update the placeholder tint. Exposes the crawler's tuning. |
| `PerimeterMovementComponent` | Own the distance along the loop, compute position and rotation on the rounded rectangle, and report the forward direction. Owns no speed or target state. |
| `TargetDetector` | Track `player` bodies inside the vision circle. Gains `get_targets()`. |
| `ContactImpactComponent` | Damage and knock back the player on contact. Unchanged. |
| `AttackReceiver` / `HealthDamageReaction` / `Health` | Receive damage. Unchanged. |
| `DestroyOnDeath` / `StardustDropOnDeath` | Free the crawler and drop Stardust. Unchanged. |
| `EnemyRespawner` | Recreate enemies with their exported configuration. |

## PerimeterMovementComponent

`entities/enemies/platform_crawler/perimeter_movement_component.gd`, class name `PerimeterMovementComponent`.

```gdscript
@export var body: Node2D
@export var platform_size: Vector2 = Vector2(192.0, 80.0)
@export_range(0.0, 200.0) var clearance: float = 12.0
@export_enum("Clockwise:1", "Counterclockwise:-1") var direction: int = 1
@export var start_distance: float = 0.0

var distance: float

func get_perimeter_length() -> float  # 2·width + 2·height + 2π·clearance
func sample(at: float) -> Transform2D  # local transform on the loop
func advance(step: float) -> void      # positive = forward in `direction`, negative = backward
func get_forward() -> Vector2          # global unit direction of travel
```

- `sample()` wraps `at` into the loop. Distance `0` is the top-left end of the top edge; increasing distance is clockwise.
- `advance()` wraps `distance` and applies `sample(distance)` to `body.transform`.
- A missing `body` reports a configuration error and the component does nothing.

## PlatformCrawler

`entities/enemies/platform_crawler/platform_crawler.gd`, class name `PlatformCrawler`, scene `PlatformCrawler.tscn`.

```gdscript
enum State { PATROL, CHARGE, RECOIL }
signal state_changed(state: State)

@export var platform_size: Vector2       # forwarded to Movement
@export var direction: int               # forwarded to Movement
@export var start_distance: float        # forwarded to Movement
@export var patrol_speed: float = 90.0
@export var charge_speed: float = 280.0
@export var acceleration: float = 700.0
@export var vision_radius: float = 240.0
@export_range(1.0, 180.0) var vision_half_angle: float = 90.0
@export_flags_2d_physics var line_of_sight_mask: int = 1
@export var recoil_distance: float = 48.0
@export var recoil_duration: float = 0.2
@export var attack_pause: float = 0.25
@export var patrol_color: Color
@export var charge_color: Color

func get_state() -> State
func get_speed() -> float
func get_target() -> Node2D
func is_in_front(point: Vector2) -> bool
func has_line_of_sight(point: Vector2) -> bool
func can_see(target: Node2D) -> bool    # in front and in line of sight
func start_recoil() -> void
```

Level placements override `platform_size`, `direction`, and `start_distance` on the root, and the root forwards them to its components in `_ready()`.

# Level 01 Placement

Both platforms in the left room are 4×2 tiles of the platform atlas. Their collision is 192 × 79.55 px in world space (the top row's collision starts 2.52 px below the tile centre, scaled ×3).

| Crawler | Tile cells | Root position | `direction` |
| --- | --- | --- | --- |
| `PlatformCrawler` | x −92…−89, y 32…33 | (−4319, 1592.2) | `1` |
| `PlatformCrawler2` | x −79…−76, y 63…64 | (−3695, 3080.2) | `-1` |

# Failure Handling

- Missing component references report configuration errors and leave the crawler idle instead of crashing.
- A freed target is ignored on the next frame.
- `platform_size` components below `0` are clamped to `0`; a clearance of `0` produces sharp corners without dividing by zero.

# Implementation Plan

1. Add `TargetDetector.get_targets()`.
2. Add `PerimeterMovementComponent`.
3. Add `PlatformCrawler` and its placeholder scene.
4. Make `EnemyRespawner` restore exported configuration.
5. Place two crawlers on the marked Level 01 platforms.
6. Add the `platform_crawler` test suite.
7. Manually verify the crawl around both platforms, front-only and line-of-sight detection, charging, repeated hits without passing through, death drop, and respawn.

# Testing

- The loop length equals `2w + 2h + 2πr`.
- Samples on each edge sit exactly `clearance` away from the platform rectangle, with rotations 0°, 90°, 180°, and 270°.
- Advancing past the loop length wraps around; `direction = -1` moves the other way.
- A player in front makes the crawler charge; a player behind leaves it patrolling.
- A player in front but behind a solid body on the line-of-sight mask is not detected.
- A contact hit starts Recoil: the crawler moves backward, pauses, and returns to Patrol.
- A player overlapping the contact area in front stops the crawler from advancing through them.
- The crawler reaches `charge_speed` while a player stays in front and returns to `patrol_speed` after the player leaves.
- Depleting `Health` frees the crawler and drops two 10-Stardust pickups.
- `EnemyRespawner` recreates a crawler with its overridden `platform_size` and `direction`.

# Acceptance Criteria

1. Each marked platform has a crawler that loops around its whole perimeter, upright relative to the surface it is on.
2. The crawler never leaves its platform.
3. A player in front within the vision radius and in line of sight makes the crawler visibly speed up; a player behind it or on the other side of its platform does not.
4. Touching the crawler damages and knocks back the player.
5. The crawler never passes through the player; it backs off after each hit and charges again, hitting repeatedly.
6. The crawler can be killed with attacks and then drops 20 Stardust in two pickups.
7. Crawlers respawn with the same platform and direction after the player dies.
