# Feature Overview

Three changes that complete the basic menu loop: the game now starts on the main menu, the Options screen lets players change volume, fullscreen, and keyboard bindings, and dying shows a loading screen for 5 seconds before play resumes.

# Behavior Rules

## Startup

- `run/main_scene` is `res://ui/main_menu/MainMenu.tscn`. The main menu offers Continue (when a save exists), Start / New Game, Options, and Quit.

## Options

- **Volume** (0–100%, steps of 5) sets the Master bus volume. 0% mutes the bus.
- **Fullscreen** switches between fullscreen and windowed. Ignored in headless runs.
- **Controls** lists every remappable action with its keyboard key. Selecting one waits for the next key press and binds it.
  - Escape cancels, except when rebinding Pause, which may take Escape.
  - If the key is already used by another action, the two actions swap keys.
  - Only keyboard keys change; controller bindings are kept.
- **Reset to defaults** restores volume 100%, windowed mode, and the project's default keys.
- **Back**, Escape, or the Pause key returns to the main menu. Options are saved to `user://settings.cfg` whenever the screen closes, and applied at startup.

## Death screen

- When the player dies (`Events.player_died`), the screen turns black immediately and a "Loading" label with a spinner appears in the bottom-right corner.
- The player respawns behind the black screen (existing `RespawnOnDeath` behavior).
- Gameplay is paused and input is blocked, including the pause menu, for `duration` (5 s).
- The overlay then fades out over `fade_out_time` (0.5 s) and play resumes.

# Implementation Details

| Component | Responsibility |
| --- | --- |
| `Settings` (autoload, `settings/settings.gd`) | Own volume, fullscreen, and key bindings; apply them to `AudioServer`, `DisplayServer`, and `InputMap`; save and load `user://settings.cfg`. |
| `OptionsMenu` (`ui/main_menu/Options.tscn`) | Present and edit the options through the `Settings` API. |
| `DeathScreen` (`entities/player/respawn/ui/DeathScreen.tscn`) | Cover the respawn, show the loading indicator, pause and block input for its duration. Placed in `Main.tscn`. |
| `LoadingSpinner` | Code-drawn rotating arc used by the death screen. |

Other UI that shows key names (checkpoint shop, sequence UI) reads them from `InputMap`, so it reflects rebinds automatically.

# Scope

Out of scope: separate music and effects volume (no audio exists yet), remapping controller buttons, resolution options, and opening Options from the pause menu.

# Acceptance Criteria

1. Launching the game shows the main menu.
2. Volume, fullscreen, and rebound keys apply immediately and persist across launches.
3. Rebinding to a key in use swaps the two actions' keys; Escape cancels a rebind.
4. Reset restores defaults.
5. Dying shows a black screen with a loading indicator in the bottom-right corner for 5 seconds, during which gameplay is paused and the pause menu cannot open; afterwards the screen fades out and play resumes at the respawn point.

Run `bash tests/options_and_death/run_tests.sh` for the automated checks.
