local api = require("api")
local SettingsCommon = require("nuzi-ui/settings_common")

local SettingsDefaults = {}

SettingsDefaults.DEFAULT_SETTINGS = {
    enabled = true,
    drag_requires_shift = true,
    update_interval_ms = 100,
    frame_scale = 1,
    alignment_grid_enabled = false,
    hide_ancestral_icon_level = false,
    hide_boss_frame_background = false,
    hide_target_grade_star = false,
    settings_button = {
        x = 10,
        y = 200,
        size = 48
    },
    cooldown_tracker = {
        enabled = false,
        update_interval_ms = 50,
        migrated_from_cbt = false,
        anchor_layout_version = 2,
        units = {
            player = {
                enabled = false,
                pos_x = 330,
                pos_y = 100,
                icon_size = 40,
                icon_spacing = 5,
                max_icons = 10,
                lock_position = false,
                show_timer = true,
                timer_font_size = 16,
                timer_color = { 255, 255, 255, 255 },
                show_label = false,
                label_font_size = 14,
                label_color = { 255, 255, 255, 255 },
                display_mode = "both",
                display_style = "icons",
                bar_width = 180,
                bar_height = 14,
                bar_fill_color = { 207, 74, 22, 255 },
                bar_bg_color = { 18, 18, 18, 220 },
                tracked_buffs = {}
            },
            target = {
                enabled = false,
                pos_x = 0,
                pos_y = -8,
                icon_size = 40,
                icon_spacing = 5,
                max_icons = 10,
                lock_position = false,
                show_timer = true,
                timer_font_size = 16,
                timer_color = { 255, 255, 255, 255 },
                show_label = false,
                label_font_size = 14,
                label_color = { 255, 255, 255, 255 },
                display_mode = "both",
                display_style = "icons",
                bar_width = 180,
                bar_height = 14,
                bar_fill_color = { 207, 74, 22, 255 },
                bar_bg_color = { 18, 18, 18, 220 },
                cache_timeout_s = 300,
                tracked_buffs = {}
            },
            playerpet = {
                enabled = false,
                pos_x = 0,
                pos_y = -8,
                icon_size = 40,
                icon_spacing = 5,
                max_icons = 10,
                lock_position = false,
                show_timer = true,
                timer_font_size = 16,
                timer_color = { 255, 255, 255, 255 },
                show_label = false,
                label_font_size = 14,
                label_color = { 255, 255, 255, 255 },
                display_mode = "both",
                display_style = "icons",
                bar_width = 180,
                bar_height = 14,
                bar_fill_color = { 207, 74, 22, 255 },
                bar_bg_color = { 18, 18, 18, 220 },
                tracked_buffs = {}
            },
            watchtarget = {
                enabled = false,
                pos_x = 0,
                pos_y = -8,
                icon_size = 40,
                icon_spacing = 5,
                max_icons = 10,
                lock_position = false,
                show_timer = true,
                timer_font_size = 16,
                timer_color = { 255, 255, 255, 255 },
                show_label = false,
                label_font_size = 14,
                label_color = { 255, 255, 255, 255 },
                display_mode = "both",
                display_style = "icons",
                bar_width = 180,
                bar_height = 14,
                bar_fill_color = { 207, 74, 22, 255 },
                bar_bg_color = { 18, 18, 18, 220 },
                tracked_buffs = {}
            },
            target_of_target = {
                enabled = false,
                pos_x = 0,
                pos_y = -8,
                icon_size = 40,
                icon_spacing = 5,
                max_icons = 10,
                lock_position = false,
                show_timer = true,
                timer_font_size = 16,
                timer_color = { 255, 255, 255, 255 },
                show_label = false,
                label_font_size = 14,
                label_color = { 255, 255, 255, 255 },
                display_mode = "both",
                display_style = "icons",
                bar_width = 180,
                bar_height = 14,
                bar_fill_color = { 207, 74, 22, 255 },
                bar_bg_color = { 18, 18, 18, 220 },
                tracked_buffs = {}
            }
        }
    },
    cast_bar = {
        enabled = false,
        width = 500,
        scale = 1.1,
        pos_x = 0,
        pos_y = 0,
        position_initialized = false,
        lock_position = false,
        fill_style = "texture",
        bar_texture_mode = "auto",
        border_thickness = 4,
        fill_color = { 245, 199, 107, 255 },
        bg_color = { 13, 10, 8, 230 },
        accent_color = { 240, 204, 122, 36 },
        text_color = { 255, 255, 255, 255 },
        text_offset_x = 0,
        text_offset_y = 6,
        text_font_size = 15
    },
    travel_speed = {
        enabled = false,
        pos_x = 260,
        pos_y = 170,
        width = 220,
        scale = 1,
        font_size = 20,
        lock_position = false,
        only_vehicle_or_mount = false,
        show_bar = true,
        show_state_text = true
    },
    gear_loadouts = {
        enabled = false,
        show_icons = false,
        bar_pos_x = 420,
        bar_pos_y = 240,
        editor_pos_x = 520,
        editor_pos_y = 170,
        lock_bar = false,
        lock_editor = false,
        button_size = 38,
        button_width = 126,
        characters = {}
    },
    nameplates = {
        enabled = false,
        guild_only = false,
        guild_colors = {},
        show_raid_party = true,
        show_watchtarget = true,
        show_mount = true,
        show_target = true,
        show_player = false,
        show_guild = true,
        alpha_pct = 100,
        width = 100,
        hp_height = 28,
        mp_height = 4,
        max_distance = 130,
        x_offset = 0,
        y_offset = 22,
        anchor_to_nametag = true,
        bg_enabled = true,
        bg_alpha_pct = 80,
        name_font_size = 14,
        guild_font_size = 11,
        debuffs = {
            enabled = false,
            show_timer = true,
            show_secondary = true,
            tracking_scope = "focus",
            anchor = "top",
            max_icons = 4,
            icon_size = 30,
            secondary_icon_size = 18,
            timer_font_size = 11,
            gap = 4,
            offset_x = 0,
            offset_y = -8,
            show_hard = true,
            show_silence = true,
            show_root = true,
            show_slow = true,
            show_dot = true,
            show_misc = true
        }
    },
    style = {
        large_hpmp = true,
        hp_font_size = 16,
        mp_font_size = 11,
        overlay_font_size = 12,
        overlay_alpha = 1,
        overlay_shadow = true,
        gs_font_size = 12,
        class_font_size = 12,
        target_guild_font_size = 12,
        target_guild_offset_x = 10,
        target_guild_offset_y = -18,
        target_guild_visible = true,
        target_class_visible = true,
        target_gearscore_visible = true,
        target_pdef_visible = true,
        target_mdef_visible = true,
        target_guild_color = { 255, 255, 255, 255 },
        target_class_color = { 255, 255, 255, 255 },
        target_gearscore_color = { 255, 255, 255, 255 },
        target_pdef_color = { 255, 255, 255, 255 },
        target_mdef_color = { 255, 255, 255, 255 },
        name_font_size = 14,
        name_shadow = true,
        name_visible = true,
        name_offset_x = 0,
        name_offset_y = 0,
        level_visible = true,
        level_font_size = 12,
        level_offset_x = 0,
        level_offset_y = 0,
        target_grade_star_offset_x = 0,
        target_grade_star_offset_y = 0,
        value_shadow = true,
        hp_value_offset_x = 0,
        hp_value_offset_y = 0,
        mp_value_offset_x = 0,
        mp_value_offset_y = 0,
        value_format = "stock",
        short_numbers = false,
        bar_colors_enabled = false,
        hp_bar_height = 18,
        mp_bar_height = 18,
        bar_gap = 0,
        hp_bar_color = { 223, 69, 69, 255 },
        mp_bar_color = { 86, 198, 239, 255 },
        hp_fill_color = { 223, 69, 69, 255 },
        hp_after_color = { 223, 69, 69, 255 },
        mp_fill_color = { 86, 198, 239, 255 },
        mp_after_color = { 86, 198, 239, 255 },
        hp_texture_mode = "stock",
        hp_custom_texture_path = "",
        hp_custom_texture_key = "",
        buff_windows = {
            enabled = false,
            player = {
                buff = {
                    anchor = "TOPLEFT",
                    x = 0,
                    y = -42
                },
                debuff = {
                    anchor = "TOPLEFT",
                    x = 0,
                    y = -66
                }
            },
            target = {
                buff = {
                    anchor = "TOPLEFT",
                    x = 0,
                    y = -42
                },
                debuff = {
                    anchor = "TOPLEFT",
                    x = 0,
                    y = -66
                }
            }
        },
        aura = {
            enabled = false,
            icon_size = 24,
            icon_x_gap = 2,
            icon_y_gap = 2,
            buffs_per_row = 10,
            sort_vertical = false,
            reverse_growth = false
        },
        frames = {
            player = {},
            target = {},
            watchtarget = {},
            target_of_target = {},
            party = {
                frame_scale = 0.55
            }
        }
    },
    player = {
        x = 10,
        y = 300
    },
    target = {
        x = 10,
        y = 380
    },
    watchtarget = {
        x = 10,
        y = 460
    },
    target_of_target = {
        x = 10,
        y = 540
    },
    frame_width = 320,
    frame_height = 64,
    bar_height = 18,
    font_size_value = 12,
    show_distance = true,
    frame_alpha = 1,
    role = {
        tanks = {
            "Abolisher",
            "Skullknight"
        },
        healers = {
            "Cleric",
            "Hierophant"
        }
    }
}

function SettingsDefaults.DeepCopyTable(obj, visited)
    if type(obj) ~= "table" then
        return obj
    end
    visited = visited or {}
    if visited[obj] ~= nil then
        return visited[obj]
    end
    local out = {}
    visited[obj] = out
    for k, v in pairs(obj) do
        out[SettingsDefaults.DeepCopyTable(k, visited)] = SettingsDefaults.DeepCopyTable(v, visited)
    end
    return out
end

function SettingsDefaults.CopyDefaultValue(value)
    if type(value) == "table" then
        return SettingsDefaults.DeepCopyTable(value)
    end
    return value
end

function SettingsDefaults.MergeInto(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then
        return
    end

    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            SettingsDefaults.MergeInto(dst[k], v)
        elseif v ~= nil then
            dst[k] = v
        end
    end
end

local function NormalizeGuildKey(raw)
    local k = tostring(raw or "")
    k = string.match(k, "^%s*(.-)%s*$") or k
    k = string.lower(k)
    k = string.gsub(k, "%s+", "_")
    k = string.gsub(k, "[^%w_]", "")
    if k ~= "" and string.match(k, "^%d") ~= nil then
        k = "_" .. k
    end
    return k
end

local function EnsureTableDefault(parent, key, defaultValue)
    if type(parent) ~= "table" then
        return
    end
    if type(defaultValue) == "table" then
        if type(parent[key]) ~= "table" then
            parent[key] = SettingsDefaults.DeepCopyTable(defaultValue)
        end
        for childKey, childValue in pairs(defaultValue) do
            EnsureTableDefault(parent[key], childKey, childValue)
        end
        return
    end
    if parent[key] == nil then
        parent[key] = defaultValue
    end
end

local function MigrateLegacyTargetOverlayLayout(styleTable)
    local changed = false
    if type(styleTable) ~= "table" then
        return changed
    end

    local legacyTogglesMissing =
        styleTable.target_guild_visible == nil
        and styleTable.target_class_visible == nil
        and styleTable.target_gearscore_visible == nil
        and styleTable.target_pdef_visible == nil
        and styleTable.target_mdef_visible == nil

    if legacyTogglesMissing and tonumber(styleTable.target_guild_offset_y) == -54 then
        styleTable.target_guild_offset_y = -18
        changed = true
    end

    if styleTable.target_glider_visible ~= nil then
        styleTable.target_glider_visible = nil
        changed = true
    end
    if styleTable.target_glider_color ~= nil then
        styleTable.target_glider_color = nil
        changed = true
    end

    return changed
end

function SettingsDefaults.EnsureCooldownTrackerDefaults(s)
    if type(s) ~= "table" then
        return
    end

    if type(s.cooldown_tracker) ~= "table" then
        s.cooldown_tracker = {}
    end
    if type(s.cooldown_tracker.units) ~= "table" then
        s.cooldown_tracker.units = {}
    end

    for k, v in pairs(SettingsDefaults.DEFAULT_SETTINGS.cooldown_tracker) do
        if s.cooldown_tracker[k] == nil then
            s.cooldown_tracker[k] = SettingsDefaults.CopyDefaultValue(v)
        end
    end

    local function ensureUnit(key)
        if type(s.cooldown_tracker.units[key]) ~= "table" then
            s.cooldown_tracker.units[key] = {}
        end
        for unitKey, unitValue in pairs(SettingsDefaults.DEFAULT_SETTINGS.cooldown_tracker.units[key]) do
            if s.cooldown_tracker.units[key][unitKey] == nil then
                s.cooldown_tracker.units[key][unitKey] = SettingsDefaults.CopyDefaultValue(unitValue)
            end
        end
        if type(s.cooldown_tracker.units[key].tracked_buffs) ~= "table" then
            s.cooldown_tracker.units[key].tracked_buffs = {}
        end
    end

    ensureUnit("player")
    ensureUnit("target")
    ensureUnit("playerpet")
    ensureUnit("watchtarget")
    ensureUnit("target_of_target")
end

local function NormalizeTrackerColor(raw)
    if type(raw) ~= "table" then
        return { 255, 255, 255, 255 }
    end
    local out = {}
    for i = 1, 4 do
        local value = tonumber(raw[i])
        if value == nil then
            value = 255
        elseif value <= 1 then
            value = value * 255
        end
        if value < 0 then
            value = 0
        elseif value > 255 then
            value = 255
        end
        out[i] = math.floor(value + 0.5)
    end
    return out
end

function SettingsDefaults.TryMigrateCooldownTrackerFromCbt(s)
    if type(s) ~= "table" or type(s.cooldown_tracker) ~= "table" then
        return false
    end
    if s.cooldown_tracker.migrated_from_cbt then
        return false
    end

    local cbt = api.GetSettings("CooldawnBuffTracker")
    if type(cbt) ~= "table" then
        s.cooldown_tracker.migrated_from_cbt = true
        return true
    end

    local function migrateUnit(srcKey, dstKey)
        if type(cbt[srcKey]) ~= "table" then
            return
        end
        local src = cbt[srcKey]
        local dst = s.cooldown_tracker.units[dstKey]
        if type(dst) ~= "table" then
            return
        end

        if src.enabled ~= nil then
            dst.enabled = src.enabled and true or false
        end
        if src.posX ~= nil then
            dst.pos_x = tonumber(src.posX) or dst.pos_x
        end
        if src.posY ~= nil then
            dst.pos_y = tonumber(src.posY) or dst.pos_y
        end
        if src.iconSize ~= nil then
            dst.icon_size = tonumber(src.iconSize) or dst.icon_size
        end
        if src.iconSpacing ~= nil then
            dst.icon_spacing = tonumber(src.iconSpacing) or dst.icon_spacing
        end
        if src.lockPositioning ~= nil then
            dst.lock_position = src.lockPositioning and true or false
        end
        if src.showTimer ~= nil then
            dst.show_timer = src.showTimer and true or false
        end
        if src.timerFontSize ~= nil then
            dst.timer_font_size = tonumber(src.timerFontSize) or dst.timer_font_size
        end
        if type(src.timerTextColor) == "table" then
            dst.timer_color = NormalizeTrackerColor({
                src.timerTextColor.r,
                src.timerTextColor.g,
                src.timerTextColor.b,
                src.timerTextColor.a
            })
        end
        if src.showLabel ~= nil then
            dst.show_label = src.showLabel and true or false
        end
        if src.labelFontSize ~= nil then
            dst.label_font_size = tonumber(src.labelFontSize) or dst.label_font_size
        end
        if type(src.labelTextColor) == "table" then
            dst.label_color = NormalizeTrackerColor({
                src.labelTextColor.r,
                src.labelTextColor.g,
                src.labelTextColor.b,
                src.labelTextColor.a
            })
        end
        if type(src.trackedBuffs) == "table" then
            dst.tracked_buffs = {}
            for _, v in ipairs(src.trackedBuffs) do
                table.insert(dst.tracked_buffs, v)
            end
        end
        if srcKey == "target" and src.cacheTimeout ~= nil then
            dst.cache_timeout_s = tonumber(src.cacheTimeout) or dst.cache_timeout_s
        end
    end

    SettingsDefaults.EnsureCooldownTrackerDefaults(s)
    migrateUnit("player", "player")
    migrateUnit("target", "target")
    migrateUnit("playerpet", "playerpet")
    migrateUnit("watchtarget", "watchtarget")
    migrateUnit("target_of_target", "target_of_target")

    if cbt.enabled ~= nil then
        s.cooldown_tracker.enabled = cbt.enabled and true or false
    end

    s.cooldown_tracker.migrated_from_cbt = true
    return true
end

local function MigrateCooldownTrackerAnchorOffsets(s)
    if type(s) ~= "table" or type(s.cooldown_tracker) ~= "table" then
        return false
    end

    local tracker = s.cooldown_tracker
    local version = tonumber(tracker.anchor_layout_version) or 0
    if version >= 2 then
        return false
    end

    local changed = false
    local units = type(tracker.units) == "table" and tracker.units or {}
    local legacyDefaults = {
        target = { x = 330, y = 170 },
        playerpet = { x = 330, y = 30 },
        watchtarget = { x = 330, y = 240 },
        target_of_target = { x = 330, y = 310 }
    }

    for unitKey, legacy in pairs(legacyDefaults) do
        local unitCfg = units[unitKey]
        if type(unitCfg) == "table" then
            local x = tonumber(unitCfg.pos_x)
            local y = tonumber(unitCfg.pos_y)
            if x == legacy.x and y == legacy.y then
                unitCfg.pos_x = 0
                unitCfg.pos_y = -8
                changed = true
            end
        end
    end

    tracker.anchor_layout_version = 2
    return changed
end

function SettingsDefaults.EnsureSettingsDefaultsAndMigrations(s)
    if type(s) ~= "table" then
        return false
    end

    local forceWrite = false
    local defaults = SettingsDefaults.DEFAULT_SETTINGS
    local legacyRootKeys = {
        "font_size_name",
        "show_mana"
    }

    for k, v in pairs(defaults) do
        EnsureTableDefault(s, k, v)
    end

    if type(s.cast_bar) == "table"
        and s.cast_bar.position_initialized ~= true
        and tonumber(s.cast_bar.width) == 420
        and tonumber(s.cast_bar.scale) == 1.25 then
        s.cast_bar.width = defaults.cast_bar.width
        s.cast_bar.scale = defaults.cast_bar.scale
        forceWrite = true
    end

    for _, key in ipairs(legacyRootKeys) do
        if s[key] ~= nil then
            s[key] = nil
            forceWrite = true
        end
    end

    if MigrateLegacyTargetOverlayLayout(s.style) then
        forceWrite = true
    end
    if MigrateLegacyTargetOverlayLayout(s.style.frames and s.style.frames.target) then
        forceWrite = true
    end

    if type(s.nameplates.guild_colors) ~= "table" then
        s.nameplates.guild_colors = {}
        forceWrite = true
    end

    SettingsDefaults.EnsureCooldownTrackerDefaults(s)
    if SettingsDefaults.TryMigrateCooldownTrackerFromCbt(s) then
        SettingsDefaults.EnsureCooldownTrackerDefaults(s)
        forceWrite = true
    end
    if MigrateCooldownTrackerAnchorOffsets(s) then
        forceWrite = true
    end

    do
        local guildColors = s.nameplates.guild_colors
        local migrated = false
        local moves = {}
        for k, v in pairs(guildColors) do
            local kstr = tostring(k or "")
            local norm = NormalizeGuildKey(kstr)
            if norm ~= "" and norm ~= kstr then
                table.insert(moves, { from = k, to = norm, value = v })
            end
        end
        for _, move in ipairs(moves) do
            if guildColors[move.to] == nil then
                guildColors[move.to] = move.value
            end
            guildColors[move.from] = nil
            migrated = true
        end
        if migrated then
            forceWrite = true
        end
    end

    if s.nameplates.click_through_shift ~= nil then
        s.nameplates.click_through_shift = nil
        forceWrite = true
    end
    if s.nameplates.click_through_ctrl ~= nil then
        s.nameplates.click_through_ctrl = nil
        forceWrite = true
    end
    if s.raidframes ~= nil then
        s.raidframes = nil
        forceWrite = true
    end
    if s.dailies ~= nil then
        s.dailies = nil
        forceWrite = true
    end
    if s.dailyage ~= nil then
        s.dailyage = nil
        forceWrite = true
    end
    if s.style.minimal ~= nil then
        s.style.minimal = nil
        forceWrite = true
    end

    do
        local function pruneCastFields(style)
            if type(style) ~= "table" then
                return false
            end
            local changed = false
            for _, key in ipairs({
                "cast_bar_enabled",
                "cast_bar_height",
                "cast_font_size",
                "cast_fill_color",
                "cast_after_color"
            }) do
                if style[key] ~= nil then
                    style[key] = nil
                    changed = true
                end
            end
            return changed
        end

        local function pruneGradientFields(style)
            if type(style) ~= "table" then
                return false
            end
            local changed = false
            for _, key in ipairs({
                "hp_gradient_enabled",
                "hp_gradient_end_color",
                "mp_gradient_enabled",
                "mp_gradient_end_color"
            }) do
                if style[key] ~= nil then
                    style[key] = nil
                    changed = true
                end
            end
            return changed
        end

        if pruneCastFields(s.style) then
            forceWrite = true
        end
        if pruneGradientFields(s.style) then
            forceWrite = true
        end
        if type(s.style.frames) == "table" then
            for _, key in ipairs({ "player", "target", "watchtarget", "target_of_target", "party" }) do
                if pruneCastFields(s.style.frames[key]) then
                    forceWrite = true
                end
                if pruneGradientFields(s.style.frames[key]) then
                    forceWrite = true
                end
            end
        end
    end

    if SettingsCommon.PruneStyleFrameOverrides(s, { "player", "target", "watchtarget", "target_of_target", "party" }) then
        forceWrite = true
    end

    return forceWrite
end

return SettingsDefaults
