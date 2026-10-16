# Architecture

This Godot game uses feature-driven organization and composition over inheritance. A feature owns its scenes, scripts, resources, presentation, and dedicated artwork. Entity controllers coordinate focused components; shared components are extracted when multiple features actually consume them. `AGENTS.md` contains the project-wide conventions.

## Project organization

```text
Main.tscn / main.gd                Application composition and dependency wiring
events.gd                         Cross-feature event signals
entities/
  player/                         Player controller, inventory, equipment, stats, sprites
    input/                        Player aim input
    movement/                     Player jump and knockback components
    reactions/                    Player action reactions
    respawn/                      Player spawn/checkpoint state and death response
  enemies/
    basic_skeleton/               Concrete enemy scene, controller, and sprites
    combat/                       Enemy melee, hitbox, and contact behavior
    detection/                    Enemy target detection
    platform_crawler/             Enemy that loops around one platform and charges forward
    respawn/                      Enemy recreation after player death
  interactive/
    checkpoint/                   Reusable checkpoint scene, logic, and menu
    door/                         Door scene and controller
    lever/                        Physical lever, presentation, and push reaction
  items/
    item_definition.gd            Public item metadata contract
    definitions/                  Concrete item resources
    pickup/                       Item pickup scene and interaction script
    reactions/                    Physics-item action reactions
    sprites/                      Item-specific artwork and source files
  dummy/                          Combat test entity and its damage animation
currency/
  coin_manager.gd                 Autoload owning the currency total
  drop/                           Death-triggered Stardust drops composed into enemies
  pickup/                         Currency pickup scene and behavior
  ui/                             Currency display
health/                           Shared health and generic death policies
spells/
  core/                           Casting, definitions, registry, database, cooldowns
  action/                         Action contracts and concrete action spells
  attack/                         Attack contracts, spell commands, and projectiles
  dash/ / double_jump/            Concrete movement spells
  ui/                             Spell sequence, cooldown, and registry presentation
components/                       Components with consumers across features
levels/level_01/                  Level composition, camera, and level artwork
ui/                               General menus and the player HUD
assets/pickups/                   Placeholder artwork shared by items and currency
prototypes/                       Background rendering experiment and debug artwork
  editor_recovery/                Historical editor snapshots, excluded from imports
tests/                            Feature suites and the shared headless runner
docs/specs/                       Feature behavior and acceptance criteria
```

## Ownership and dependencies

| Owner | Authoritative state or responsibility |
| --- | --- |
| `SpellDatabase` | Shared catalogue of spell definitions. |
| `SpellRegistry` | One player's registered spell IDs. |
| `SpellCooldowns` | Active cooldown end times, accepted durations, and start order. |
| `Health` | Health, shield, and depletion events. |
| `Inventory` / `Equipment` | Item quantities and equipped slots, changed through public APIs. |
| `RespawnOnDeath` | Player spawn position, checkpoint, and respawn lifecycle. |
| `EnemyRespawner` | Placed enemy definitions and transforms used for recreation. |
| `SwitchComponent` | Discrete switch state consumed by doors. |
| `CoinManager` | Currency total and its change signal. |

`Main` composes the level and application UI and supplies player dependencies to the pause menu. Features exchange data through public methods, typed data objects, signals, and explicitly assigned references. Components do not discover unrelated nodes by traversing arbitrary paths.

The player owns its movement coordination and exposes narrow capabilities such as `try_spell_jump()`, `collect_item()`, and `set_checkpoint()`. Checkpoints request a saved destination through that capability; they do not modify player health or movement state. `RespawnOnDeath` emits lifecycle signals so the player can clear movement modes before position and health are restored.

The `Events` autoload publishes `player_died` and `item_collected`. The enemy respawner and item-notification display subscribe to those public events. It owns no gameplay state. The `CoinManager` autoload is the currency feature's application-lifetime state owner.

Shared `components/` contains the action/attack receiver contracts, health damage reaction, switch state, gravity, horizontal movement, and character-to-rigid-body pushing. Player-only movement and input components remain inside the player feature. Generic behavior may move to shared components when a second feature demonstrates reuse.

## Runtime flow

```mermaid
flowchart TD
    Main[Main composition] --> Player[Player feature]
    Main --> Menus[General UI]
    Main --> Level[Level composition]
    Level --> Enemies[Enemy feature]
    Level --> Interactive[Checkpoint, lever, and door features]
    Level --> Pickups[Item and currency pickups]
    Player --> Caster[SequenceCaster]
    Caster --> Registry[SpellRegistry]
    Registry --> Database[SpellDatabase]
    Caster --> Invoker[SpellInvoker]
    Invoker --> Cooldowns[SpellCooldowns]
    Invoker --> Command[SpellCommand instance]
    Command --> Effects[ActionData / AttackData]
    Effects --> Receivers[Shared receivers and composed reactions]
    Receivers --> Health[Health]
    Receivers --> Movement[Entity movement / physics]
    Cooldowns --> SpellUI[Spell UI]
    Health --> Respawn[Player respawn / entity destruction]
```

Commands and projectiles own their temporary lifetime. UI observes authoritative gameplay state and requests changes through APIs. Shared resources contain configuration; per-player and per-entity runtime state remains in node components.

## Working on a feature

Read its specification, keep new files with its owner, and update explicit references when moving resources. Preserve script and asset UID sidecars during moves. Keep scripts beside their scenes or in focused subdirectories within the feature. Use `tests/` and `docs/specs/` for feature verification and contracts; see `TESTING.md` for execution details.
