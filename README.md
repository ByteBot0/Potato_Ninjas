# HookRex Arena

Linux-first Godot 4 prototype for a 2D side-view arena shooter built around a permanent grappling hook.

## Direction Notes

The prototype is moving toward a ninja arena theme:

- Ninjas with grappling hooks instead of dinos with guns
- Throwing stars as the base weapon direction
- Bo staff melee
- Possible pickups such as kusarigama, rapid throwing stars, poison blowdarts, metsubushi, smoke/defense tools, and later grenades/bombs if they still fit
- Future player-grappling where hooks can pull opponents in, with clear break rules
- Future cosmetic achievement unlocks such as skins, uniforms, masks, hook variants, titles, and badges
- Unlocks should not make experienced players stronger than new players
- Future movement experiments: ducking and dashing
- Future map dressing: custom backgrounds plus foreground bushes/trees/bamboo for concealment

## Current Build

Phase 7: Android Readiness

- Placeholder ninja character
- Generated rectangle arena
- Gravity, running, jumping, and fast fall
- Mouse-aimed right-click grappling hook
- Limited hook range
- Hook collision against platform surfaces only
- Rope and hook tip rendering
- Auto-reel pull toward the hook point
- Hanging near walls, ceilings, and platforms while right mouse is held
- Momentum-preserving detach on right mouse release
- Left-click throwing stars
- Projectile collision against platforms, bots, and the player
- Shooting while grounded, airborne, hooked, and hanging
- 3-minute offline deathmatch timer
- 4 simple rival ninjas that chase, jump, shoot, take damage, and respawn
- Player health, death, respawn, score, deaths, and results overlay
- Environmental deaths subtract one player point
- Weapon pickup spawn points with respawn timers
- Kusarigama, rapid star, and poison dart pickups
- Health and shield pickups
- Limited ammo and timed pickup behavior
- Rival ninjas can seek weapon pickups
- Rival ninjas seek health when hurt
- Rival ninjas retreat when low health and no health pickup is available
- Rival ninjas check for hazards before committing to movement
- Rival ninjas use pickup weapons with simplified ninja-tool behavior
- Hit sparks, pickup burst effects, and death bursts
- Light camera shake for hits, explosions, pickups, and defeats
- Camera framing keeps the player lower on screen so more space is visible above
- Shield pickup has an active visual ring
- Main menu with match setup options
- Rival count, rival difficulty, timer, and pickups can be configured before a match
- First LAN multiplayer prototype with Host LAN and Join LAN menu options
- Controls settings with separate gameplay and map builder bindings
- Touch-control overlay for Android-style play
- Desktop toggle for testing touch controls
- Camera follow
- Gameplay HUD with health, score, timer, weapon icon, and ammo status

## Controls

| Action | Input |
| --- | --- |
| Move | A / D |
| Jump | Space / W |
| Aim | Mouse |
| Fire | Hold left mouse |
| Bo staff melee | F |
| Grapple | Hold right mouse |
| Release grapple | Release right mouse |
| Fast fall | S |
| Restart match | R |
| Return to menu | Esc |
| Toggle touch controls | T |

## Running

Open this folder in Godot 4.x and run the project. The main scene is `res://scenes/MainMenu.tscn`.

The current project version is `0.1.0-dev`. Multiplayer players should run the same version before joining a LAN or Tailscale match. See [docs/update_workflow.md](docs/update_workflow.md) for the recommended GitHub update flow.

The menu currently supports:

| Option | Status |
| --- | --- |
| Deathmatch | Playable |
| Prototype Arena | Playable |
| Rival count | 0-8 requested, capped by available spawn points |
| Rival difficulty | Easy / Normal / Hard |
| Timer | 1-10 minutes |
| Pickups | On / off |
| Hazards | Placeholder |
| Network | Solo / Host LAN / Join LAN |
| Map Builder | Playable editor mode |

The Controls button opens remapping for gameplay and map builder actions. Bindings save to `user://input_settings.json`.

## LAN Multiplayer Prototype

The menu now has a Network row:

| Option | Use |
| --- | --- |
| Solo | Normal local match |
| Host LAN | Starts an ENet server on the selected port |
| Join LAN | Connects to the host IP and selected port |

For a first LAN test, the host chooses `Host LAN`, selects the map and match settings, then starts the match. Other players choose `Join LAN` and enter the host machine's LAN IP. The host's match settings and map data are sent to joiners, so the joiner's local map dropdown is ignored for LAN matches. Everyone should run the same project/build version.

For remote play without public port forwarding, Tailscale can be used like a private LAN. The host chooses `Host LAN`, and other players join using the host computer's Tailscale IP address.

Current LAN scope:

| Feature | Status |
| --- | --- |
| Multiple human players | Prototype |
| Remote player movement sync | Prototype with visual interpolation |
| Remote grappling hook visuals | Prototype |
| Remote player shooting | Prototype, host relays shots |
| Remote player damage | Prototype, host-authoritative projectiles |
| Score and timer sync | Prototype, host-authoritative |
| Pickups | Local prototype behavior |
| Bots in LAN | Disabled for now |
| Scoreboard | Uses synced `You / Rivals` prototype scoring |

## Map Builder

The first map builder slice is available from the Mode dropdown.

When Map Builder mode is selected, the map dropdown chooses which saved map to edit. Select `Prototype Arena` to open a blank builder canvas.

Current builder features:

| Tool | Input |
| --- | --- |
| Draw rectangle | Left mouse drag on empty space |
| Place spawn marker | Select spawn material, left click |
| Select object | Left click object |
| Move object | Left-drag object |
| Pan builder view | Right mouse drag by default, configurable in Controls |
| Recenter builder view | Home |
| Delete selected | Delete button or Delete key |
| Clear map | Clear button |
| Save map | Save button |
| Load map | Load button |
| Place scale/test ninja | Select `test_spawn`, left click |
| Test from scale ninja | Test button |
| Return to menu | Menu button or Esc |

Maps save as JSON files under Godot's `user://maps` folder. Saved maps now appear in the main menu map list and can be played in Deathmatch.

Current playable custom-map behavior:

| Material | Current Runtime Behavior |
| --- | --- |
| concrete | Solid platform/wall, hookable, blocks bullets |
| mesh | Solid platform/wall, hookable, bullets pass through |
| nograpple | Solid platform/wall, blocks bullets, hook does not attach |
| hazard | Defeat zone |
| out_of_bounds | Defeat/respawn zone |
| player_spawn | Player start and respawn point |
| test_spawn | Builder-only scale marker and Test button start point |
| bot_spawn | Bot spawn point |
| item_spawn | Pickup spawn point, cycles pickup types |

Multiple player spawn points are supported. The arena chooses one at random when the player starts or respawns.

Custom maps no longer have an invisible default out-of-bounds line. Add explicit `out_of_bounds` zones where the map should defeat or respawn players. The builder warns when leaving a map with no out-of-bounds zones.

Bots receive hazard awareness. They can drop between platforms, but try to avoid walking directly into hazard/out-of-bounds zones or through hazard/out-of-bounds zones below an edge.

## Android Notes

The prototype now includes an on-screen control overlay. It appears automatically on mobile builds and can be toggled on desktop with `T` for testing.

Touch controls:

| Action | Touch Input |
| --- | --- |
| Move | Left virtual joystick |
| Aim/fire | Right aim stick |
| Jump | J button |
| Grapple | Hold H button |
| Fire | Hold F button or drag right aim stick |
