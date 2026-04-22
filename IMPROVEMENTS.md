# Nuzi UI Improvements

## High Impact

- Split the two biggest files into smaller modules.
  - [settings_page.lua](/c:/Users/David/Documents/AAClassic/Addon/nuzi-ui/settings_page.lua) is about 5005 lines.
  - [ui.lua](/c:/Users/David/Documents/AAClassic/Addon/nuzi-ui/ui.lua) is about 3735 lines.
  - These are the best candidates for breaking into focused modules like `player_frame.lua`, `target_frame.lua`, `aura_style.lua`, `settings_sections/*.lua`, and shared widget helpers.

- Move the giant default settings schema out of [main.lua](/c:/Users/David/Documents/AAClassic/Addon/nuzi-ui/main.lua).
  - `main.lua` currently handles bootstrap, migration, file IO, defaults, backups, and addon lifecycle.
  - A dedicated `defaults.lua` and `settings_store.lua` would make the addon easier to change without risking unrelated behavior.

- Reduce duplicated module loader boilerplate.
  - [main.lua](/c:/Users/David/Documents/AAClassic/Addon/nuzi-ui/main.lua), [ui.lua](/c:/Users/David/Documents/AAClassic/Addon/nuzi-ui/ui.lua), and [settings_page.lua](/c:/Users/David/Documents/AAClassic/Addon/nuzi-ui/settings_page.lua) all repeat the same `pcall(require, "nuzi-ui/x")` then `pcall(require, "nuzi-ui.x")` pattern.
  - A single shared `safe_require` helper would simplify startup code and make load failures easier to diagnose.

- Separate stock-frame styling from addon-only overlays.
  - `nuzi-ui` currently mixes stock unitframe augmentation, nameplates, cooldown tracking, daily quest UI, and settings logic in one addon.
  - Consider clearer module boundaries:
    - stock frame styling
    - nameplates
    - cooldown tracker
    - daily tools
    - settings UI

## Settings UX

- Break the settings page into smaller builders and stronger categories.
  - [settings_page.lua](/c:/Users/David/Documents/AAClassic/Addon/nuzi-ui/settings_page.lua) is doing too much in one file.
  - Split by sections like `General`, `Player`, `Target`, `Nameplates`, `Cooldown Tracker`, `DailyAge`, and `Advanced`.

- Add “reset this section” actions.
  - Right now the settings surface looks like it is built around one large configuration state.
  - Per-section reset buttons would make experimentation much safer than full reset/import/export flows.

- Add a search/filter box for settings.
  - The addon has enough options now that discoverability is becoming a real problem.
  - Searching for terms like `glider`, `guild`, `font`, `aura`, or `nameplate` would be a big usability win.

- Show live dependency hints in the UI.
  - Example: if a feature depends on stock content availability or a blocked API, surface that next to the control instead of only relying on compatibility warnings.

- Add clearer “recommended defaults” presets.
  - A few presets like `Minimal`, `PvP`, `Information Dense`, and `Streamer Clean` would make onboarding easier.

## Performance And Reliability

- Reduce work done every update tick.
  - [ui.lua](/c:/Users/David/Documents/AAClassic/Addon/nuzi-ui/ui.lua) and [cooldown_tracker.lua](/c:/Users/David/Documents/AAClassic/Addon/nuzi-ui/cooldown_tracker.lua) both do recurring update work.
  - More event-driven refreshes and less polling would lower overhead and make frame behavior easier to reason about.

- Centralize safe API wrappers.
  - There are many `pcall`-guarded access patterns and “safe get” helpers spread around the addon.
  - A shared runtime safety layer would reduce repeated defensive code and make bugs easier to fix once.

- Add structured debug logging toggles.
  - A lightweight debug mode for `settings load`, `frame bind`, `nameplate updates`, and `target extras` would make regressions much easier to track without editing code each time.

- Add validation for loaded settings before applying them.
  - `main.lua` already does a lot of normalization.
  - A single schema-style validation pass with clear repair rules would further harden imports and legacy migrations.

## Repo Hygiene

- Stop checking generated settings backups into the addon folder.
  - [settings.txt](/c:/Users/David/Documents/AAClassic/Addon/nuzi-ui/settings.txt) plus many `settings_backup_*.txt` files are currently sitting beside source files.
  - These should live in a dedicated runtime-only backup directory and be gitignored if they are not meant to be source.

- Add a `README.md`.
  - There is no clear top-level usage doc in [nuzi-ui](/c:/Users/David/Documents/AAClassic/Addon/nuzi-ui).
  - The addon would benefit from a short install guide, feature list, command list, and known limitations section.

- Add a short architecture note.
  - Even a one-page `ARCHITECTURE.md` explaining module responsibilities would make future refactors much easier.

## Feature Ideas

- Expand stock-frame support consistency.
  - Make player, target, watchtarget, target-of-target, and nameplate options feel more uniform in wording and capability.

- Add profile support.
  - Character-specific and shared profiles would be useful for players who swap between PvP, raid, and alt setups.

- Add export/import for only one feature area.
  - Example: export only `nameplates` or only `cooldown_tracker` settings instead of the whole config.

- Add a visual alignment/editor mode.
  - The addon already has an alignment grid concept in [ui.lua](/c:/Users/David/Documents/AAClassic/Addon/nuzi-ui/ui.lua).
  - Expanding that into a full placement mode would help with custom layouts.

- Add a compatibility/health page.
  - Surface what stock content is available, what features are active, and what fallbacks are being used.

## Suggested Order

1. Split `settings_page.lua` into section modules.
2. Split `ui.lua` into frame-specific modules.
3. Move defaults/settings persistence into dedicated files.
4. Centralize safe API access and debug logging.
5. Clean up runtime backup files and add docs.
