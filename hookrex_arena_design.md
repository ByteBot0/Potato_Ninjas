# HookRex Arena — Linux-First Game Design Brief

## Goal

Build a Linux-first 2D side-view arena shooter prototype inspired by movement-focused arena games, but with original characters, weapons, maps, names, art, and sound.

The main goal is to create a game where the core movement is fun before multiplayer, polish, or advanced combat are added.

The most important mechanic is a permanent grappling hook that every player always has. Weapons are pickups, but the hook is part of the base movement kit.

## Core Gameplay Fantasy

The player controls an agile ninja in a platform arena. The ninja can run, jump, throw weapons, fight at close range, and use a grappling hook to move quickly around the map.

The hook should let the player:

- Save themselves after falling off a platform
- Pull rapidly up toward ledges, walls, and ceilings
- Swing across gaps
- Hang from a wall or ceiling while firing weapons
- Release the hook to fall, launch, or reposition
- Re-fire the hook mid-fall if another surface is within range

The game should feel fast, skill-based, and movement-driven.

## Target Platform Plan

### Primary Development Target

- Linux desktop
- Keyboard and mouse controls
- Godot 4 recommended
- 2D side-view physics prototype first

### Later Target

- Android APK
- Sideloaded to a personal phone
- Touch controls added after the Linux prototype feels good

## Visual Style

Use placeholder art for the prototype.

Recommended placeholder style:

- Ninja: simple capsule, circle, or rectangle character with a mask/headband silhouette
- Platforms: colored rectangles
- Weapons: simple ninja-themed icons or blocks
- Projectiles: circles or small rectangles
- Hook rope: simple line
- Hook point: small dot or claw marker

Do not use DinoSmash names, assets, maps, sounds, characters, UI, or copyrighted material.

### Theme Direction

The prototype began with cartoon dinosaurs, but the preferred direction is now ninjas with grappling hooks. The theme fits the hook fantasy, close-range melee, stealthy foreground objects, unlockable outfits, and projectile weapons better than the original placeholder direction.

Core theme notes:

- Player characters are stylized arena ninjas, not realistic military characters.
- The grappling hook should feel like a ninja tool used for movement, escapes, and pulling enemies into danger.
- Weapons should lean toward ninja/fantasy equipment instead of rifles and rockets.
- Maps can support stealth-flavored visuals such as forests, rooftops, temples, bamboo platforms, bushes, and foreground trees.
- Placeholder art is still fine while mechanics are being tested.

Possible alternate directions can still be revisited later if the ninja theme stops fitting the mechanics, but new gameplay and art should assume ninjas unless there is a specific reason not to.

## Progression Philosophy

The game should eventually include achievements and unlocks that encourage players to keep playing and let them show what they have accomplished.

Important rule:

- Unlocks should be cosmetic, expressive, or self-imposed challenge modifiers.
- Unlocks should not make experienced players stronger than new players.

Possible achievement rewards:

- Ninja skins
- Uniform colors and patterns
- Masks, headbands, belts, and clan emblems
- Grappling hook visual variants
- Weapon visual variants
- Player titles or profile badges
- Non-power gameplay modifiers for custom/friendly modes only

Achievement examples:

- Win a match without falling out of bounds
- Land several grappling hook saves in one round
- Defeat an opponent shortly after hooking them
- Win with only base weapons
- Get a melee elimination
- Survive while poisoned or blinded
- Build and play a custom map

## Core Controls — Linux Prototype

| Action | Control |
|---|---|
| Move left | A |
| Move right | D |
| Jump | Space or W |
| Aim | Mouse position |
| Fire weapon | Left mouse button |
| Fire / hold grappling hook | Right mouse button |
| Release grappling hook | Release right mouse button |
| Optional reel modifier | Shift |
| Optional drop / fast fall | S |

## Grappling Hook Design

The grappling hook is the most important system in the game.

### Hook Behavior Summary

The hook should **not** behave like a loose bungee cord by default.

Instead, it should behave like a fast auto-reeling grappling hook:

1. Player aims with the mouse.
2. Player holds right mouse button.
3. Hook fires toward the aim direction.
4. If the hook hits a valid surface within range, it attaches.
5. Once attached, the rope rapidly shortens.
6. The player is pulled toward the hook point.
7. If the player keeps holding right mouse button, they continue being pulled until they are close to the wall, ceiling, or platform.
8. The player can hang near the attached surface while still aiming and firing weapons.
9. Releasing right mouse button detaches the hook.
10. Once detached, the player falls or continues moving based on momentum.
11. The player can fire the hook again if another valid surface is within range.

### Hook Range

The hook should have limited range.

Initial tuning target:

- Maximum hook range: about 75% of the visible screen width

Design reason:

If the player falls off the map but reacts quickly, they can hook a nearby platform and pull themselves back up. If they wait too long and fall too far, the platform will be out of range and they cannot recover.

### Hook Attachment Rules

The hook can attach to:

- Platform edges
- Ceilings
- Walls
- Designated grapple surfaces

The hook should not attach to:

- Projectiles
- Pickups
- Non-grapple background art

### Player Grappling

Future versions should allow the grappling hook to attach to other players.

Initial design rules:

- Hooking another player pulls the target toward the hooker.
- The hook automatically releases after 10 seconds if neither player breaks it earlier.
- The hooker can release manually at any time.
- The hooked player should not be able to deal damage while being pulled unless they are unhooked or are right next to the hooker.
- The hook should break if another player damages the hooker.
- The hook should break if the target reaches close-quarters range and normal melee/combat resumes.
- This should be tuned carefully so player grappling creates exciting close-range fights without becoming a guaranteed elimination.

Implementation notes:

- In LAN, player grappling should be host-authoritative like projectile damage.
- The hooked target needs clear visual feedback so they understand why control/combat is restricted.
- The hooker needs clear visual feedback when the hook breaks because they were damaged.
- Bots can ignore this mechanic until PvP behavior feels good.

### Hook Pulling Feel

The hook should rapidly pull the player toward the hook point.

Important tuning variables:

- `max_hook_range`
- `hook_projectile_speed`
- `auto_reel_speed`
- `pull_acceleration`
- `max_pull_speed`
- `arrival_distance`
- `swing_influence`
- `detach_momentum_multiplier`
- `air_control_while_hooked`

### Hook Momentum

When the player releases the hook, they should keep some or all of their current velocity.

This is what allows:

- Swing launches
- Flying across the map
- Saving yourself from falls
- Skillful movement chains

### Hanging Behavior

If the player keeps holding right click after being pulled close to the surface, they should remain near the hook point instead of instantly detaching.

While hanging, the player should still be able to:

- Aim with the mouse
- Fire weapons
- Release the hook manually

The player should not be perfectly frozen. A slight sway or minor movement is okay, but the player should feel held near the surface.

## Combat Design

Combat should be added only after the hook movement feels good.

### Base Weapon

The player should always have a basic weak weapon.

Suggested ninja-theme base weapon:

- Throwing stars
- Infinite ammo
- Moderate fire rate
- Straight projectile or slight spread depending on tuning
- Low damage

### Permanent Melee Weapon

Players should eventually have a permanent short-range melee weapon in addition to the rifle/blaster and grappling hook.

Preferred ninja-theme melee:

- Bo staff swing

Design goals:

- Gives players a reliable close-quarters option when pickup ammo runs out
- Rewards aggressive hook movement and risky close-range engagements
- Creates a high-damage option that requires positioning skill
- Lets players fight while pressed against walls, ceilings, or other players
- Should be short range enough that it does not replace shooting

Initial tuning idea:

- Fast windup
- Short active hit window
- Noticeable cooldown
- Higher damage than the basic blaster
- Small knockback on hit

This should be added after the first pickup and bot loops are working, so melee can be balanced against real combat pressure.

### Pickup Weapons

Weapon pickups can temporarily replace or enhance the base weapon.

Suggested ninja-theme weapons:

1. Kusarigama
   - Close-range, high-damage pickup
   - Pulls nearby opponents inward
   - Damages opponents once they are close
   - Should be risky and short-range so it rewards positioning

2. Rapid throwing stars
   - Fast fire rate
   - Lower damage per shot
   - Good while swinging or hanging

3. Poison blowdarts
   - Slow projectile
   - Decent initial damage
   - Applies poison damage over time
   - Poison should deal slightly more total damage if the target cannot disengage or heal
   - Needs clear visual feedback on the poisoned player
   - Limited ammo

4. Metsubushi
   - Utility/disruption pickup
   - Temporarily blurs or obscures an opponent's vision
   - Should be annoying but short-lived, readable, and avoid making the game feel unfair
   - Needs accessibility options if heavy blur or flashing effects are added

5. Spike Toss / Kunai
   - Medium-speed projectile
   - Reliable default pickup

6. Smoke Bomb / Shield
   - Defensive pickup
   - Temporarily reduces damage
   - Could also create a brief visual screen or escape window

### Possible Future Weapons To Reevaluate

- Grenades or bombs that can be lobbed over platforms
- These could add interesting arcing attacks and area denial, but they should be reevaluated later so the weapon set does not become too noisy or explosive too early.

## Game Modes

### MVP Mode: Offline Deathmatch

The first full mode should be an offline deathmatch against bots.

Rules:

- 3-minute match timer
- Player vs bots
- Score points by defeating bots
- Respawn after defeat
- Highest score wins

### Future Menu and Match Setup

The game should eventually have a main menu before entering a match.

Suggested menu options:

- Play
- Game mode selection
- Map selection
- Bot options
- Map builder
- Settings
- Quit

### Future Keyboard Mapping

Settings should eventually include keyboard and mouse remapping.

Players should be able to rebind:

- Move left / right
- Jump
- Drop / fast fall
- Fire
- Hook
- Melee
- Restart
- Menu / pause
- Touch-control toggle for desktop testing

The remapping UI should show conflicts clearly and allow resetting to defaults.

Match setup options should include:

- Game mode
- Map
- Number of bots
- Bot difficulty
- Match timer
- Score limit
- Pickups on / off
- Hazards on / off

Future movement options to prototype:

- Ducking
  - Lets players lower their profile behind cover or under narrow spaces
  - Could pair well with foreground concealment
  - Should not make camping too strong

- Dashing
  - Short burst movement for evasive play and recovery
  - Should complement grappling rather than replacing it
  - Needs cooldown, stamina, or another limiter if it becomes too strong

Bot difficulty can start simple:

- Easy: slower aim, slower firing, less pickup awareness
- Normal: current prototype behavior
- Hard: faster aim, stronger pursuit, better pickup priority

Map building should eventually be available from this menu so players can create, test, save, and select custom arenas.

### Later Modes

Possible later modes:

- Team Deathmatch
- Capture the Fossil
- King of the Nest
- Last Dino Standing
- Local multiplayer testing
- Online multiplayer, only after the offline game is fun

## Phase Plan

## Phase 1 — Hook Playground

Purpose: prove the movement is fun.

Requirements:

- 2D side-view map
- Player character placeholder
- Gravity
- Ground movement
- Jumping
- Mouse aiming
- Right-click grappling hook
- Hook range limit
- Hook collision with valid surfaces
- Rope line rendering
- Rapid auto-reel pulling
- Hang near wall or ceiling while holding right click
- Detach when right click is released
- Preserve momentum on release
- Camera follows player
- Basic debug UI

Debug UI should show:

- Player velocity
- Hook state
- Hook distance
- Whether hook is attached
- Current reel speed or pull force
- Whether player is grounded

Success criteria:

The player can move around the test map using the hook and it feels fun even with no enemies or weapons.

## Phase 2 — Basic Shooting

Purpose: prove that shooting while moving, swinging, or hanging works.

Requirements:

- Mouse aiming
- Left-click firing
- Basic projectile
- Projectile collision
- Simple damageable target dummies
- Player can shoot while grounded
- Player can shoot while falling
- Player can shoot while hooked
- Player can shoot while hanging near a wall or ceiling

Success criteria:

The hook and weapon systems work together without fighting each other.

## Phase 3 — Arena Combat Prototype

Purpose: create the first playable match loop.

Requirements:

- One arena map
- Health system
- Damage system
- Respawn system
- 3-minute timer
- Score tracking
- Win/loss/results screen
- 3 to 4 simple bots
- Bots can move, jump, chase, and shoot
- Bots do not need advanced hook behavior yet

Success criteria:

The player can complete a full match against bots.

## Phase 4 — Weapon Pickups

Purpose: make the arena more dynamic.

Requirements:

- Weapon pickup spawn points
- Pickup respawn timers
- Shotgun pickup
- Machine gun pickup
- Rocket or egg launcher pickup
- Health pickup
- Shield pickup
- Limited ammo or timed pickup behavior

Success criteria:

Players are encouraged to move around the map and fight over pickups.

## Phase 5 — Better Bots

Purpose: make offline play more interesting.

Requirements:

- Bots can seek weapons
- Bots can chase player
- Bots can retreat at low health
- Bots can fire at player
- Bots can navigate platforms
- Optional simple hook usage for bots

Success criteria:

Bots create enough pressure to make the arena feel alive.

## Phase 6 — Game Feel and Polish

Purpose: improve responsiveness and fun.

Requirements:

- Better movement tuning
- Better hook tuning
- Hit effects
- Screen shake for impacts
- Sound effects
- Simple music loop
- Better placeholder sprites
- Menu screen
- Pause screen
- Settings screen

Success criteria:

The game feels satisfying before Android work begins.

## Phase 7 — Android Port

Purpose: move the stable Linux prototype to Android.

Requirements:

- Android export setup
- Touch movement controls
- Touch aiming controls
- Hook button
- Fire button
- Jump button
- Mobile UI scaling
- Performance testing on phone
- APK sideload testing

Suggested Android controls:

| Action | Touch Control |
|---|---|
| Move | Left virtual joystick |
| Aim | Right virtual joystick or drag area |
| Fire | Fire button |
| Hook | Hook button, hold to stay attached, release to detach |
| Jump | Jump button |

Success criteria:

The game can be sideloaded and played comfortably on a personal Android phone.

## Future Map Materials and Builder

Maps should eventually support different surface materials instead of treating every wall, ceiling, and platform the same way.

Material rules should be explicit so level design can create readable combat spaces.

Suggested material types:

1. Concrete / solid wall
   - Players collide with it
   - Hook can attach
   - Bullets cannot pass through
   - Good for normal platforms, walls, ceilings, and cover

2. Mesh / grate
   - Players collide with it or optionally pass through depending on map use
   - Hook can attach
   - Bullets can pass through
   - Good for aggressive movement routes that do not provide full cover

3. No-grapple wall
   - Players collide with it
   - Hook cannot attach
   - Bullets may or may not pass through depending on material variant
   - Good for boundaries or areas where hook routes should be limited

4. Out-of-bounds volume
   - Does not need to be visible
   - Defines how far players can fall or move before respawning
   - Allows maps with deeper pits or larger recovery zones

5. Hazard / kill volume
   - Touching it defeats or damages the player
   - Useful for lava, spikes, acid, void zones, grinders, or other arena hazards

6. Background art
   - No player collision
   - Hook cannot attach
   - Bullets do not collide
   - Purely visual

7. Foreground concealment
   - Decorative objects such as bushes, bamboo, tree trunks, hanging cloth, or roof beams
   - Can partially cover players for stealth and mind games
   - Should not fully hide important combat information unless that is an intentional map feature
   - Needs readability tuning so concealment feels clever instead of unfair

### Material Debugging

During development, surfaces should be easy to inspect.

Helpful debug display options:

- Show collision surfaces
- Show hookable surfaces
- Show bullet-blocking surfaces
- Show out-of-bounds zones
- Show hazard zones
- Show foreground concealment zones

This will make it easier to catch bugs where bullets pass through a wall that should block them, or where the hook attaches to a surface that should be decorative only.

### Background and Foreground Art

Future maps should support custom backgrounds and foreground dressing.

Initial direction:

- Forest backgrounds
- Night rooftops
- Bamboo groves
- Temple courtyards
- Mountains or moonlit sky layers

Foreground objects:

- Bushes
- Trees
- Bamboo clusters
- Tall grass
- Hanging banners or cloth
- Roof beams

Design goals:

- Let map creators make arenas feel like places rather than only blockouts.
- Let players try to conceal themselves behind foreground elements.
- Keep silhouettes, health bars, hook lines, and hit effects readable enough for fair combat.
- Consider an editor toggle to show/hide foreground objects while building.

### Map Builder Idea

A future in-game or editor-adjacent map builder could allow quick arena creation with simple paint-style tools.

Suggested builder tools:

- Draw square / rectangle
- Draw circle
- Free draw shape
- Erase
- Move / resize object
- Set object material type
- Set spawn points
- Set weapon pickup points
- Set out-of-bounds zones
- Set hazard / kill zones
- Set custom background
- Place foreground concealment objects

The first version does not need advanced art tools. It could be a practical blockout builder focused on gameplay iteration:

1. Draw geometry.
2. Assign material.
3. Place player and bot spawns.
4. Test the map immediately.
5. Save the map data.

This would make it easy to build arenas with intentional movement routes, cover, hook lanes, bullet-through mesh, and dangerous fall zones.

## Suggested Godot Project Structure

```text
HookRexArena/
├── project.godot
├── scenes/
│   ├── MainMenu.tscn
│   ├── TestArena.tscn
│   ├── Player.tscn
│   ├── BotDino.tscn
│   ├── Projectile.tscn
│   ├── Pickup.tscn
│   └── UI.tscn
├── scripts/
│   ├── Player.gd
│   ├── GrappleHook.gd
│   ├── WeaponController.gd
│   ├── Projectile.gd
│   ├── BotDino.gd
│   ├── Health.gd
│   ├── Pickup.gd
│   ├── PickupSpawner.gd
│   ├── GameManager.gd
│   ├── UIManager.gd
│   └── CameraFollow.gd
├── assets/
│   ├── placeholder/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
└── docs/
    └── hookrex_arena_design.md
```

## Suggested First Codex Prompt

```text
Create a Godot 4 Linux desktop project prototype using this design brief.

Focus only on Phase 1 first: the hook playground.

Build a 2D side-view physics test arena with a placeholder player, platforms, gravity, movement, jumping, mouse aiming, and a right-click grappling hook.

The hook must have limited range, attach only to valid surfaces, rapidly auto-reel the player toward the hook point, allow the player to hang near the surface while right click is held, detach when right click is released, and preserve momentum on release.

Add debug text showing player velocity, hook state, hook distance, attached status, reel speed or pull force, and grounded status.

Use placeholder art only and keep scripts organized.
```

## Design Priorities

1. Hook movement must feel good.
2. Shooting while hooked must work.
3. Movement skill should matter more than weapon strength.
4. Offline bots come before online multiplayer.
5. Linux desktop comes before Android.
6. Android touch controls come only after the core game is stable.
7. Use original assets, names, maps, and sounds.
