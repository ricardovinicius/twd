# Feature Overview

Interacting moved to **Down** on keyboard and controller, every gameplay action now answers to a controller input, and the camera only looks up or down while the player stands completely still.

# Behavior Rules

## Controller layout

| Input | Action |
| --- | --- |
| A | Jump; OK in menus and dialogue |
| B / X / Y | Spell tokens: Move (L) / Attack (J) / Interaction (K) |
| Right trigger | Confirm spell (I) |
| Left stick, D-pad | Move, aim, menu navigation |
| D-pad down, left stick down | Interact (also aims down) |
| R3 | Cancel dialogue |
| B | Back in menus (also the Move token in gameplay) |
| LB / RB | Previous / next pause-menu tab |
| Start | Pause |
| Back | Select |

- Every controller binding uses "all devices", so a controller in any slot works. Interact and Cancel used to accept only controller 0.
- Aim up and Aim down gained D-pad up and down; before, only the stick aimed vertically.

## Interacting with Down

- Interact is S on the keyboard, D-pad down, and the left stick pushed firmly down (deadzone 0.6, so a light diagonal while walking does not interact).
- Down still aims down and, with Jump, drops through platforms. Interacting only happens when a target is selected, so pressing down elsewhere does nothing new.
- E no longer interacts; E and RB still switch pause-menu tabs.
- Interact is not remappable on its own. It always follows the Aim down key (`Settings.LINKED_ACTIONS`); the Settings row is labeled "Down: Aim / Interact / Drop".
- Prompts show the active device's label: "S" on keyboard, "D-pad Down" on controller.

## OK and Back

- `ui_accept` (OK) is Enter, Space, and A; `ui_cancel` (Back) is Esc and B. Godot's defaults had no controller buttons for either, so menus could be navigated but not confirmed with a controller.
- In menus, A presses the focused button. B closes an open section and then resumes from the pause menu, like Pause.
- In dialogue, OK advances to the next line, alongside Down. The press that advances or closes a conversation does not also make the player jump. Jumping while talking otherwise still works.
- OK alone never starts a conversation; Down does.
- The dialogue hint shows the OK button ("A  Continue" or "Enter  Continue"). Prompts use short controller names (A, B, LB, D-pad Down).

## Looking up and down

- The camera looks up or down only when the player is on the floor, has no velocity, is not holding left or right, and has no interaction target selected (so holding down to talk does not move the camera).
- Walking, jumping, falling, or riding knockback ends the look and the camera recenters. Stopping while still holding the direction starts looking again after the hold threshold.

# Acceptance Criteria

1. Each controller button and axis in the table triggers its action from any controller slot.
2. S, D-pad down, and the stick pushed down start a conversation with a nearby NPC; E does not.
3. Remapping Aim down moves Interact to the same key; Reset restores S.
4. A presses focused menu buttons and advances dialogue without jumping; B goes back in the pause menu.
5. Holding up or down while standing still moves the camera; while walking or in the air it does not.

Run `bash tests/controller_input/run_tests.sh` for the automated checks.
