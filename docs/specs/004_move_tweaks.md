# Feature Overview

In order to create a more dynamic and responsive movement system, we will be implementing several tweaks to the existing movement mechanics. These changes aim to enhance player control, improve responsiveness, and provide a more engaging gameplay experience.

Including:
- Adjusting movement speed and acceleration to create a more fluid and responsive feel.
- Adding acceleration and deceleration curves to smooth out transitions between different movement states.
- Adding coyote time to allow players to jump shortly after leaving a platform, making the game feel more forgiving and responsive.
- Implementing variable jump height based on how long the jump button is held, allowing for more precise control over jumps.
- Adding a jump buffer to allow players to queue jump inputs, making it easier to perform jumps in fast-paced situations.
- Increase the gravity of falling to make the player feel more grounded and responsive when falling.
- Implement a "push off ledges" mechanic, making the player move around the top of ledges more naturally and allowing for more dynamic movement in platforming scenarios.

# Implementation Details

## Movement Speed and Acceleration
- Create a three variable system
    - `max_speed`: The maximum speed the player can reach while moving.
    - `acceleration`: The rate at which the player accelerates to their maximum speed.
    - `deceleration`: The rate at which the player slows down when stopping or changing direction.
- Adjust these values to create a more fluid and responsive movement feel.

## Coyote Time
- Implement a timer that starts when the player leaves a platform, allowing them to jump for a short period of time after leaving the ground.
- The duration of coyote time can be adjusted to balance responsiveness and challenge.
- The coyote time is reset when the player lands on a platform or when they jump, ensuring that the mechanic only applies to the initial jump after leaving a platform.

## Variable Jump Height
- Implement a system that allows the player to control the height of their jump based on how long the jump button is held down.
- Apply an initial jump impulse.
- While rising, releasing jump multiplies upward velocity by a configurable factor (e.g., 0.5) to reduce jump height.
- Holding jump will allow the player to reach the maximum jump height, while releasing it early will result in a shorter jump.

## Jump Buffer
- Implement a jump buffer that allows players to queue jump inputs, making it easier to perform jumps in fast-paced situations.
- The jump buffer will store the jump input for a short duration, allowing the player to jump even if they press the jump button slightly before landing on a platform.
- The duration of the jump buffer can be adjusted to balance responsiveness and challenge.
- The jump buffer is reset when the player lands on a platform or when they jump, ensuring that the mechanic only applies to the initial jump after leaving a platform.

## Gravity Adjustment
- Increase the gravity applied to the player when falling to make the player feel more grounded and responsive
- The gravity value can be adjusted to balance responsiveness and challenge.
- A down-gravity value will be applied when the player is falling, which will be higher than the normal gravity value applied when the player is ascending.

_Note:_ The features ahead will be implemented in a future update, but are included here for completeness.

## Push Off Ledges
- Implement a mechanic that allows the player to push off ledges when moving around the top of ledges, making the movement feel more natural and dynamic.
- When the player jumps and bumps into a ledge, the game moves the player slightly away from the ledge, allowing them to push off and continue moving in the desired direction.



