# Testing

Automated suites use standalone `SceneTree` scripts with headless Godot. Import the project in Godot before running tests from a fresh checkout so global classes and imported assets are available. Load scene fixtures from the deferred test entry point, after autoload registration.

Run all suites from the project root:

```bash
for runner in tests/*/run_tests.sh; do
    bash "$runner" || exit 1
done
```

Set `GODOT_BIN` to select a Godot executable. Suites start through `tests/bootstrap.gd`, which loads the suite after autoloads are registered, so suites and the scripts they load may reference autoloads such as `CoinManager`. Each suite uses `tests/run_suite.sh`, which creates isolated data, configuration, cache, and log directories under `${TMPDIR:-/tmp}/twd-test.*`.

| Runner directory | Behavior covered |
| --- | --- |
| `initial_mob` | Enemy behavior, attack pipeline, projectiles, contact, player health, and respawn cleanup. |
| `cooldown_ui` | Cooldown entry presentation, ordering, lifecycle, and rejection. |
| `doors_and_levers` | Switch state, lever physics, push interactions, door transitions, obstruction safety, and level wiring. |
| `spell_registry` | Catalogue queries (six spells), per-player availability, dynamic casting, and registry UI. |
| `double_jump` | Grounded and airborne casting, the single air charge and its recharge on landing, cooldowns, and movement-mode coordination. |
| `jump_down` | One-way platform traversal and collision restoration. |
| `npcs_and_dialogue` | Shared target selection, dialogue lifecycle, live movement/casting, input, interruptions, and pause integration. |
| `checkpoint` | Reusable checkpoint placement, menu focus, Save/Back, duplicate protection, and player spawn integration. |
| `platform_crawler` | Perimeter loop geometry, front-only detection, charge speed, death drop, and respawn configuration. |
| `flying_eye` | Flying Eye composition, patrol bounds, sight through walls, wind-up and bolt firing, cooldown and rejection, bolt filtering, obstacles and lifetime, death drop, respawn, and monster guide entry. |
| `homunculus_couple` | Kissing couple composition, mid-kiss stare toward the player, damage skipping the stare, walls blocking sight, fast chase that ignores vision while on screen, giving up off screen and kissing again, deaths and drops, respawn, and monster guide entry. |
| `health_orb` | `Health.heal`, the player heal capability, orbs falling then releasing, collection, full-health rejection, collecting on landing, and dropping from a carrier's hand. |
| `life_moth` | Moth composition, patrol, fleeing within its speed and height band, being catchable with effort, calming down, orb drop, respawn, and monster guide entry. |
| `dung_beetle` | Beetle play and orb toss, fleeing while rolling the orb, being catchable with effort, walls cornering it, calming after a delay, orb drop, respawn, and monster guide entry. |
| `star_man` | Star Man sight through walls, scream, invulnerable roll at speed with spin, bounded turn-backs, wall bounces, dizzy vulnerability and re-rolling, forgetting a far player, drops, respawn, and monster guide entry. |
| `scorpion_man` | Scorpion Man toughness, attack choice by distance, walking closer then slamming, tail slam, butt-pincer leap across the room with its cooldown, uninterrupted attacks, drops, respawn, and monster guide entry. |
| `stardust_drop` | Enemy Stardust drops, pickup amounts, player-only collection, and `CoinManager.add_coins`. |
| `stardust_gravity` | Stardust pickups falling onto world collision, ignoring other layers, attraction suspending and resuming the fall, collection while falling, and enemy drops landing. |
| `dash` | Dash speed profile (ease-in from the current speed, ease-out to walking speed), tick-counted duration, rejection and cancellation, and smooth player speed through and after a dash. |
| `grimoire` | Grimoire companion composition and size, smooth follow through walls, side switching, teleport snapping, removed targets, and Level 01 wiring. |
| `dig` | Dig spell definition and sequence, one-hit block breaking, unsupported actions, player casting, and Level 01 block placement. |
| `spell_shop` | Shop offers, locked multi-token spells, Stardust spending and rejection, checkpoint menu purchase flow. |
| `save_system` | Resting at checkpoints (health, enemy recreation), save/load round trip, missing saves, and the checkpoint Save button. |
| `qa_fixes` | QA regressions: saved pickups stay collected, equipment limited to owned copies, levers behind the caster, New Game confirmation, menu key conflicts, restart label, shaft B corridor, and walkable elevator landings. |
| `elevator_landings` | Level traversal around the elevators: crossing corridors on the platforms, walking onto and off every landing, riding, and calling with levers. |
| `controller_input` | Controller layout for every action on any controller slot, OK (A) and Back (B) in menus and dialogue without jumping, interacting with Down (S, D-pad down, stick down), Interact following a remapped Down key, and the camera only looking up or down while the player stands still. |
| `elevator` | Elevator trips, crush guard, riding, toggle and pass-through levers, Level 01 placement and opened shaft, WASD menu navigation. |
| `spell_effects` | Push reaching receivers in every direction and pushing them away, push radius, Magic Arrow passing through walls and stopping on the first enemy. |
| `burn` | Burn definition (J + J) and shop rule, burn reactions on every enemy, fireball hit and ignition, ticking and going out, refresh without stacking, plain attacks not igniting, the rolling Star Man, and casting from the player. |
| `pause_menu` | Pause menu tabs and navigation, inventory artifacts and status, sections, monster guide, spell details, settings tab, and quit actions. |
| `options_and_death` | Startup scene, settings persistence, key rebinding and swaps, options menu, and the death loading screen. |
| `standards` | Integration regressions for lifecycle signals, explicit dependencies, cooldown reconnection, inventory, and equipment. |

The runner fails on unsuccessful process exits, script or engine errors, or a missing `PASS:` completion marker. It ignores only the known macOS system certificate lookup diagnostic emitted in sandboxed headless runs. A frame limit prevents a stalled suite from running indefinitely.

Prefer component checks before full-scene integration. Assert observable behavior and acceptance criteria, including rejected operations, cleanup, and interactions between features. Tests may use feature-owned components without moving those components into shared production folders.

Headless tests do not establish final visual quality. Manually verify HUD readability, animation appearance, camera tracking, checkpoint presentation, and physics interactions when those aspects change.
