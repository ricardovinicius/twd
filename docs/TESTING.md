# Testing

Automated suites use standalone `SceneTree` scripts with headless Godot. Import the project in Godot before running tests from a fresh checkout so global classes and imported assets are available. Load scene fixtures from the deferred test entry point, after autoload registration.

Run all suites from the project root:

```bash
for runner in tests/*/run_tests.sh; do
    bash "$runner" || exit 1
done
```

Set `GODOT_BIN` to select a Godot executable. Each suite uses `tests/run_suite.sh`, which creates isolated data, configuration, cache, and log directories under `${TMPDIR:-/tmp}/twd-test.*`.

| Runner directory | Behavior covered |
| --- | --- |
| `initial_mob` | Enemy behavior, attack pipeline, projectiles, contact, player health, and respawn cleanup. |
| `cooldown_ui` | Cooldown entry presentation, ordering, lifecycle, and rejection. |
| `doors_and_levers` | Switch state, lever physics, push interactions, door transitions, obstruction safety, and level wiring. |
| `spell_registry` | Catalogue queries, per-player availability, dynamic casting, and registry UI. |
| `double_jump` | Grounded and airborne casting, the single air charge and its recharge on landing, cooldowns, and movement-mode coordination. |
| `jump_down` | One-way platform traversal and collision restoration. |
| `npcs_and_dialogue` | Shared target selection, dialogue lifecycle, live movement/casting, input, interruptions, and pause integration. |
| `checkpoint` | Reusable checkpoint placement, menu focus, Save/Back, duplicate protection, and player spawn integration. |
| `platform_crawler` | Perimeter loop geometry, front-only detection, charge speed, death drop, and respawn configuration. |
| `stardust_drop` | Enemy Stardust drops, pickup amounts, player-only collection, and `CoinManager.add_coins`. |
| `standards` | Integration regressions for lifecycle signals, explicit dependencies, cooldown reconnection, inventory, and equipment. |

The runner fails on unsuccessful process exits, script or engine errors, or a missing `PASS:` completion marker. It ignores only the known macOS system certificate lookup diagnostic emitted in sandboxed headless runs. A frame limit prevents a stalled suite from running indefinitely.

Prefer component checks before full-scene integration. Assert observable behavior and acceptance criteria, including rejected operations, cleanup, and interactions between features. Tests may use feature-owned components without moving those components into shared production folders.

Headless tests do not establish final visual quality. Manually verify HUD readability, animation appearance, camera tracking, checkpoint presentation, and physics interactions when those aspects change.
