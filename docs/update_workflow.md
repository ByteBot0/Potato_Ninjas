# HookRex Arena Update Workflow

## Recommended Setup

Use GitHub for the source project and GitHub Releases for play sessions.

The smoothest pattern is:

1. The main updater changes the game in the repo.
2. A version is tagged, such as `v0.1.0`.
3. Everyone downloads or pulls the same version before playing.
4. Personal maps and profile data stay in Godot's `user://` save folder, so updates do not overwrite them.

This is more reliable than having the live game replace itself from the host while players are connected.

## For Players

If players run the project from Godot:

```bash
git pull
```

If players use exported builds, download the same release package from GitHub Releases.

Everyone should match the version shown on the main menu before joining a LAN or Tailscale match.

## For The Host

Before a play session:

```bash
git status
git pull
```

Then tell everyone which tag, release, or branch to use.

For Tailscale play, host with `Host LAN`, then other players use the host machine's Tailscale IP address.

## Personal Content

Keep personal content outside the repo by default:

- Maps: `user://maps`
- Controls: `user://input_settings.json`
- Future profile/unlocks: `user://profile.json`, `user://unlocks.json`
- Future skins/cosmetics: `user://skins` or a separate intentionally shared content folder

Shared maps can later be added through an export/import flow, or by creating a separate `community_maps/` folder that is intentionally versioned.

## Version Rules

The game has a version string in `VERSION` and `GameSettings.GAME_VERSION`.

When the multiplayer protocol changes, update both before tagging a release. LAN clients with a different version are rejected with a clear message instead of silently joining an incompatible match.
