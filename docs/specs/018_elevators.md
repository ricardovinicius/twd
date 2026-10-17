# Feature Overview

Two vertical shafts in Level 01 are elevators. Each has a platform that travels between a bottom and a top stop and one lever at each landing. Pushing either lever (Push spell) sends the platform to the other stop. Menus can also be navigated with the movement keys (WASD by default).

# Behavior Rules

## Elevator

- The platform starts at its bottom stop (or top, with `start_at_top`) and is solid ground the player can stand on and ride.
- Any state change of a connected switch starts one trip to the other stop. Changes during a trip are ignored.
- Motion is eased at both ends; `speed` sets the average pace.
- While descending, the elevator waits if a character or physics body is in the `CrushGuard` area under the platform, and continues once it is clear.
- Cables are drawn from the platform to an anchor `cable_anchor_height` above the top stop.
- The platform top is flush with each landing floor so the player walks on and off.

## Elevator levers

- `toggle_on_any_push`: each push flips the lever to its other state, whatever direction it comes from (also vertical pushes). The player can therefore use the same lever from the landing and from the platform.
- `blocks_movement = false`: characters walk through the lever; it is drawn behind them. Pushes still reach it.
- Both options default to the original behavior, so door levers are unchanged.

## Placement (Level 01)

| Elevator | Shaft (x) | Bottom stop (y) | Top stop (y) | Levers |
| --- | --- | --- | --- | --- |
| `ElevatorA` | 1872–2256 | 5376 (left exit) | 3312 (left exit) | `ElevatorALeverBottom` (1830, 5376), `ElevatorALeverTop` (1830, 3312) |
| `ElevatorB` | −1296 to −912 | 3216 (right exit) | 1008 (upper corridor) | `ElevatorBLeverBottom` (−870, 3216), `ElevatorBLeverTop` (−1340, 1008) |

Shaft B was capped by the upper corridor's floor. The 16 floor tiles over the shaft (`TileMapPrincipal1` cells x −27…−20, y 21–22) were removed so the platform reaches the corridor; while the elevator is below, that opening is a drop into the shaft. The striped tiles inside both shafts are decorative and have no collision.

## Menu navigation

- `Settings` mirrors the movement bindings onto `ui_up` / `ui_down` / `ui_left` / `ui_right` (aim_up, aim_down, left, right → W, S, A, D by default). Arrow keys and controller inputs keep working. Remapping a movement key moves its menu binding too.

# Implementation Details

| Component | Responsibility |
| --- | --- |
| `Elevator` (`entities/interactive/elevator/`) | Trip state, platform motion (`AnimatableBody2D`), crush guard, cables. Listens to `SwitchComponent.state_changed`. |
| `Lever` | Optional pass-through collision and toggle mode, forwarded to `LeverImpulseReaction`. |
| `LeverImpulseReaction` | In toggle mode, applies full torque toward the opposite state. |
| `Settings` | Menu navigation keys derived from movement bindings. |

# Out of Scope

Elevator art (placeholder deck and cables), sounds, saving elevator positions (they reset to their start stop on load), and call buttons inside the platform.

# Acceptance Criteria

1. Pushing either lever of an elevator sends it to the other stop; the player rides it and walks off at the landing.
2. The player can push the same lever from the landing and from the platform.
3. The elevator waits instead of descending onto a body.
4. Players walk through elevator levers; door levers still block and remain direction-dependent.
5. W/A/S/D move the focus in the main menu, options, and pause menu.

Run `bash tests/elevator/run_tests.sh` for the automated checks.
