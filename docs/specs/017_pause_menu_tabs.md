# Feature Overview

The in-game menu (Pause: Esc / Start) is a full-screen, tabbed menu following the inventory mockup: black panels with white borders. It has four tabs, switched with `menu_tab_prev` / `menu_tab_next` (Q / E, LB / RB) or by clicking the tab buttons. Tabs wrap around.

# Tabs

## Inventário

- **Artefatos**: three slots (the player's `Equipment` slots). Selecting one opens a list of inventory items to equip, plus *Remover artefato* when the slot is filled.
- **Figura do personagem**: Dona's sprite and name.
- **Status**: HP, Escudo, Insight, Dam. ARC/SAN/COL/FLE/MEL, Res. ARC/SAN/COL/FLE/MEL, Peso, Movespeed. Signed values are blue when positive and red when negative. Elemental damage bonuses do not exist in gameplay yet and always read +0.
- **Canalizador**: placeholder slot; channelers do not exist yet.
- **Seções**: *Correntes* (placeholder), *Itens gerais* (inventory items with quantities), *Guia dos monstros* (entries from `entities/enemies/bestiary/bestiary.tres`: portrait, health, damage, Stardust, weakness, description).

## Magias

- Lists every spell in the `SpellDatabase`. Spells the player does not own are dimmed and marked *(bloqueada)*.
- Selecting a spell shows its symbol (icon), name, learned/locked status, keys (from current bindings), cooldown, and effect (`SpellDefinition.description`).
- Debug builds show *Registro (debug)*, which opens the existing `SpellRegistryDebugUI`.

## Configurações

- The shared `OptionsPanel` (also used by the main menu's Options screen): Áudio (master volume), Vídeo (fullscreen, V-Sync), Controles (keyboard remapping). See `016_options_and_death_screen.md`.

## Sair

- Continuar jogando, Recomeçar do último checkpoint, Sair para o menu inicial, Sair do jogo. Settings are saved before leaving.

# Behavior Rules

- Pause opens the menu on the Inventário tab and pauses the game; Pause again resumes.
- While a section (item picker, monster guide, etc.) or the debug registry is open, Pause closes it instead of the menu, and tab switching is disabled.
- Switching tabs cancels a pending key capture in Configurações.

# Implementation Details

| Component | Responsibility |
| --- | --- |
| `PauseMenu` (`ui/pause_menu/`) | Tabs, inventory/spell presentation, quit actions. Reads and changes state only through `Equipment`, `Inventory`, `Health`, `PlayerStats`, and `SpellRegistry` APIs. |
| `OptionsPanel` (`ui/options/`) | Shared settings UI. |
| `Bestiary` / `MonsterEntry` (`entities/enemies/bestiary/`) | Monster guide data (presentation only). |
| `menu_theme.tres` (`ui/theme/`) | Black panel / white border style shared by the menus. |

# Acceptance Criteria

1. Pause shows the Inventário tab with the mockup layout.
2. Q/E and LB/RB cycle the four tabs; clicking a tab opens it.
3. Artifact slots equip and remove items; the status panel updates immediately.
4. Itens gerais, Correntes, and Guia dos monstros open and close with Voltar or Pause.
5. Magias lists all spells with symbol, name, keys, effect, and cooldown.
6. Configurações changes volume, video, and controls.
7. Sair resumes, restarts, returns to the main menu, or quits.

Run `bash tests/pause_menu/run_tests.sh` for the automated checks.
