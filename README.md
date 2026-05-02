# Nuzi UI

![Nuzi UI](icon.png)

Because the stock frames are fine right up until you actually want them to look useful.

`Nuzi UI` keeps the important frame cleanup in one place:

- styles the stock `player`, `target`, `watchtarget`, `target of target`, and stock `party` frames
- adds an optional movable player cast bar built on the stock X2 casting widget
- adds an optional travel speed meter for vehicles, mounts, gliders, and on-foot movement
- adds optional mount/glider movement-ability timers in their own settings page
- adds optional per-character gear loadouts with a clickable swap bar and drag/drop editor
- supports optional custom nameplates with matching layout controls
- adds tracked cooldown and effect windows for `player`, `target`, `watchtarget`, and `target of target`
- includes target overlay extras, aura layout controls, and a movable launcher icon
- includes a `UI Repair` page for UI scale diagnostics and safe layout resets
- supports backups, imports, and persistent settings in `.data`

## Install

1. Install via Addon Manager.
2. Make sure the addon is enabled in game.
3. Click the launcher icon to show or hide the settings window.

Saved data lives in `nuzi-ui/.data` so your layout, cooldown tracking, and settings survive updates.

## Quick Start

1. Open the `Nuzi UI` settings from the launcher icon.
2. Pick which frame group you want to edit and adjust text, bars, auras, or plates.
3. Enable only the overlays you actually want visible.
4. If you want a player cast bar, travel speed meter, mount/glider timers, or gear loadouts, enable them on their pages and move them with `Shift + drag`.
5. If you use cooldown tracking, add effects by ID, search, or scan and place each tracker where it fits your UI.
6. If frames look wrong after changing UI scale, open `UI Repair` and use Refresh, Reset Frames, or Center Frames.

This is the addon version of looking at the stock UI and saying "we can do better than this."

## How To

### Main Frames

The frame editor lets you restyle the stock combat frames without replacing how AAClassic works.

You can adjust:

- text layout, font sizes, and value formatting
- HP and MP bar colors, textures, and spacing
- aura positioning and count
- separate styling for `player`, `target`, `watchtarget`, `target of target`, `party`, or `all frames`

### Nameplates

Nameplates are optional and can be enabled separately from the frame restyle work.

You can:

- show custom raid and party overhead bars
- tune spacing, visibility, and text display
- keep them aligned with the rest of the addon styling

### Cooldowns

The cooldown tracker is built into `Nuzi UI`.

You can:

- track buffs or debuffs on `player`, `target`, `watchtarget`, and `target of target`
- add tracked effects by ID, by search, or by scanning a unit
- enter a cooldown length for tracked effects so the timer can count down after the buff appears
- show active effects, missing effects, or both
- switch each tracker between compact icons and icon-plus-bar rows
- attach non-player trackers near their nameplate and move them with offsets

Mount and glider ability buttons use internal client cooldown APIs that are not exposed to addons, so they are handled by the dedicated `Mount/Glider` page instead of this generic tracker.

### Mount/Glider

The Mount/Glider page adds a dedicated movement-ability tracker for the mounts, gliders, and magithopters you choose.

You can:

- choose one mount and one glider or magithopter from dropdown menus
- choose which abilities from those devices should show on the bar
- show ready icons dimmed and active timers bright
- track visible mount and glider buffs from both the player and mount units
- show the ability cooldown countdown after a tracked movement buff appears
- detect shared hidden glider timers from mount/glider mana use
- notify in chat when a tracked movement timer is ready
- resize icons, spacing, icons per row, and timer text
- move the strip with `Shift + drag`
- lock its position once it is where you want it
- share learned mount, glider, and magithropter definitions from `.data/mount_glider_devices.txt`

### Cast Bar

The cast bar page adds a player-only cast bar using AAClassic's stock casting widget.

You can:

- enable or disable it separately from the other frame styling work
- resize it with width and scale controls
- switch between textured and solid-color fill styles
- control the border thickness
- move it with `Shift + drag`
- lock its position once it is where you want it

### Travel Speed

The travel page adds a compact speed meter styled to sit with the ArcheAge HUD.

You can:

- show live vehicle speed when the siege/vehicle API reports it
- fall back to movement speed measured from player world-position deltas
- resize and scale the panel
- move it with `Shift + drag`
- lock its position once it is where you want it

### Gear Loadouts

The loadouts page enables a per-character gear swap bar and in-game editor.

You can:

- create, name, save, and delete gear loadouts per character
- drag bag gear onto character-style equipment slots in the editor
- save the currently equipped gear into the selected loadout
- show loadout buttons as names or chosen item icons
- warn on missing items or slot mismatches before a swap runs

### Settings And Backups

The settings window also handles profile safety tools.

You can:

- check your current screen size and UI scale on the `UI Repair` page
- reset saved frame, cast bar, travel speed, mount/glider, loadout, launcher, nameplate, or cooldown positions
- save backups
- list previous backups
- import a backup by index
- keep your UI setup in `.data/settings.txt` instead of shipping someone else's layout

## Notes

- The launcher icon, settings window, overlays, cooldown trackers, cast bar, travel speed meter, mount/glider strip, and loadout UI all save their positions.
- Learned mount, glider, and magithropter definitions also save to `.data/mount_glider_devices.txt` so they can be shared without copying another player's UI layout.
- Cooldown tracker windows for non-player units use nameplate-relative offsets instead of fixed screen coordinates.
- Backup files live in `.data/backups`.
- Moving addon windows follows the same `Shift + drag` behavior as the other Nuzi addons.

3.0.0
