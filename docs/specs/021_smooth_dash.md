# Feature Overview

The Dash spell (`spells/dash/`) used to snap the player's horizontal velocity to the dash speed, hold it for the duration counted by a `SceneTreeTimer`, and then set `velocity.x = 0`. Dashing while already running felt like a stutter, and the end of the dash felt like a whip: the player stopped dead while the smoothed camera, which lagged behind during the dash, kept travelling to catch up, so the character appeared to snap backward on screen before accelerating again from zero.

The dash now lives in a focused `DashMovementComponent` that eases in from the current speed, eases out to the walking top speed, and hands that speed back to normal movement. Its duration is counted in physics ticks.

## Goals

- Smooth entry and exit with no single-tick speed jump when dashing from walking speed.
- Keep the dash's feel: same duration, same peak speed, a fast burst at the start.
- Move dash state out of `player.gd` into a component, per `AGENTS.md`.

## Non-Goals

- Changing the Dash spell's speed multiplier, duration, cooldown, or input sequence.
- Changing the camera script. The camera whip disappears because the player no longer stops dead.
- Air dashes in vertical directions.

# Behavior Rules

- A dash has a direction, a dash speed, a duration, an entry speed, and an exit speed.
- Entry speed is the body's current velocity along the dash direction (never negative).
- Peak speed is `max(dash speed, entry speed)`: a dash never slows down a body that already moves faster than the dash.
- Exit speed is the player's walking top speed (`HorizontalMovementComponent.max_speed`), clamped to the peak.
- Speed profile over the dash progress `p` (0..1):
  - `p < ease_in_ratio` (default `0.1`): rise from entry to peak with a quadratic ease-out (fast start).
  - middle: peak speed.
  - `p > 1 - ease_out_ratio` (default `0.35`): settle from peak to exit with `smoothstep`.
- The last tick returns the exit velocity and finishes the dash. On the next tick normal movement continues from that velocity: with the direction held, the player keeps walking at top speed; with no input, normal deceleration brings the player to a stop over a few ticks.
- The dash ignores gravity and keeps vertical velocity at zero, as before.
- Knockback, a successful spell jump, and respawning cancel the dash. Cancelling emits `dash_finished` once.
- `Player.begin_dash()` returns when the dash finishes or is cancelled, so `DashSpell` completes in both cases.

## Physics interpolation

The dash only changes velocity inside `Player._physics_process`, so interpolated rendering and the physics-processed camera see continuous motion. The old `SceneTreeTimer` ended the dash in an idle frame; the tick-counted duration removes that mismatch.

# Scene Composition

```text
Player (CharacterBody2D, player.gd)
├── HorizontalMovement
├── Knockback
├── Dash (DashMovementComponent)   new
└── ...
```

| Component | Responsibility |
| --- | --- |
| `DashMovementComponent` (`entities/player/movement/dash_movement_component.gd`) | Dash state, speed profile, tick-counted duration, cancellation, and `dash_started` / `dash_finished`. |
| `Player` | Movement-mode coordination: chooses dash vs. normal vs. knockback movement, passes the current velocity and walking top speed, cancels the dash on knockback, spell jumps, and respawn. |
| `HorizontalMovementComponent` | Unchanged; takes over from the dash's exit velocity. |
| `DashSpell` | Unchanged; awaits `begin_dash`. |

# Public Contracts

```gdscript
class_name DashMovementComponent
extends Node

signal dash_started(direction: Vector2, peak_speed: float, duration: float)
signal dash_finished

@export var ease_in_ratio: float = 0.1
@export var ease_out_ratio: float = 0.35

func begin(direction: Vector2, speed: float, duration: float, current_velocity: Vector2, exit_speed: float) -> bool
func calculate_velocity(delta: float) -> Vector2
func is_active() -> bool
func get_direction() -> Vector2
func cancel() -> void
```

- `begin` returns `false` without changes while a dash is active. A zero direction or non-positive speed/duration is reported with `push_error` and rejected.
- `Player.is_dashing` is a read-only view of `Dash.is_active()`.
- `Player.begin_dash(direction, speed, duration)` keeps its signature. A zero direction falls back to `facing_direction` with an error, as before.

# Failure Handling

- A dash requested while dashing is rejected with an error and does not change the active dash.
- A cancelled dash never changes velocity later (no pending timer).

# Implementation Plan

1. Add `DashMovementComponent` and compose it as `Player/Dash`.
2. Replace the player's dash fields and timer with the component.
3. Add the `dash` test suite; keep `double_jump` and `initial_mob` dash checks passing.
4. Manually dash from standstill, from a run, into a wall, and with/without the direction held, watching the camera.

# Testing

`tests/dash/`:

- From standstill: moves on the first tick, reaches dash speed, lasts `round(duration / delta)` ticks, ends at the exit speed, finishes once.
- From walking speed: never below walking speed, largest per-tick change ≤ 120 px/s.
- Faster than the dash: the first tick keeps the faster speed.
- Rejection while active and repeated cancel.
- Player integration: speed changes smoothly through and after the dash, momentum remains after it ends, and no-input deceleration follows.
- `begin_dash` returns after the dash's ticks and after a knockback interruption.

# Acceptance Criteria

1. Dashing while running has no visible hitch at the start.
2. Ending a dash blends into walking (direction held) or a short slide (no input); the character does not snap backward on screen.
3. The dash still feels like a fast burst with the same duration and cooldown.
4. Knockback, spell jumps, and respawn still interrupt the dash safely.
