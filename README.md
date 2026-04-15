# Nuzi UI

Nuzi UI augments the stock player, target, watchtarget, target-of-target, and stock party frames, plus optional nameplates, aura layout controls, target overlay extras, and tracked cooldown icons.

## Main Parts

- `main.lua`
  - addon bootstrap
  - lifecycle hooks
  - command handling
- `ui.lua`
  - stock frame styling and overlay orchestration
- `settings_page.lua`
  - settings window and controls
- `nameplates.lua`
  - nameplate overlays
- `cooldown_tracker.lua`
  - tracked buff and debuff icon windows for player, target, pet, watchtarget, and target of target

## New Support Modules

- `safe_require.lua`
  - shared slash-or-dot module loading
- `settings_common.lua`
  - shared settings-page helpers
- `settings_widgets.lua`
  - shared settings-page widget builders
- `settings_defaults.lua`
  - default settings and migration rules
- `settings_store.lua`
  - settings load/save/backup/import logic
- `ui_alignment.lua`
  - alignment grid behavior
- `ui_target_extras.lua`
  - target overlay widgets and updates
- `settings_catalog.lua`
  - settings page registry

## Commands

- `!nui`
  - toggle overlays
- `!nui settings`
  - open settings
- `!nui backup`
  - save a backup
- `!nui backups`
  - list backups
- `!nui import <n>`
  - import a backup by index

## Notes

- Runtime backup files belong in `nuzi-ui/.data/backups/`.
- Root-level `settings_backup_*.txt` files are treated as legacy fallback paths only.
- Cooldown tracker settings are saved inside the normal `nuzi-ui/.data/settings.txt` file.
