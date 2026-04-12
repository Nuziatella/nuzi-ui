local api = require("api")

local SettingsDefaults = {}

SettingsDefaults.DEFAULT_SETTINGS = {
    enabled = true,
    drag_requires_shift = true,
    update_interval_ms = 100,
    frame_scale = 1,
    alignment_grid_enabled = false,
    dailyage = {
        enabled = false,
        hidden = {}
    },
    cooldown_tracker = {
        enabled = false,
        update_interval_ms = 50,
        migrated_from_cbt = false,
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
                timer_color = { 1, 1, 1, 1 },
                show_label = false,
                label_font_size = 14,
                label_color = { 1, 1, 1, 1 },
                tracked_buffs = {}
            },
            target = {
                enabled = false,
                pos_x = 330,
                pos_y = 170,
                icon_size = 40,
                icon_spacing = 5,
                max_icons = 10,
                lock_position = false,
                show_timer = true,
                timer_font_size = 16,
                timer_color = { 1, 1, 1, 1 },
                show_label = false,
                label_font_size = 14,
                label_color = { 1, 1, 1, 1 },
                cache_timeout_s = 300,
                tracked_buffs = {}
            },
            playerpet = {
                enabled = false,
                pos_x = 330,
                pos_y = 30,
                icon_size = 40,
                icon_spacing = 5,
                max_icons = 10,
                lock_position = false,
                show_timer = true,
                timer_font_size = 16,
                timer_color = { 1, 1, 1, 1 },
                show_label = false,
                label_font_size = 14,
                label_color = { 1, 1, 1, 1 },
                tracked_buffs = {}
            },
            watchtarget = {
                enabled = false,
                pos_x = 330,
                pos_y = 240,
                icon_size = 40,
                icon_spacing = 5,
                max_icons = 10,
                lock_position = false,
                show_timer = true,
                timer_font_size = 16,
                timer_color = { 1, 1, 1, 1 },
                show_label = false,
                label_font_size = 14,
                label_color = { 1, 1, 1, 1 },
                tracked_buffs = {}
            },
            target_of_target = {
                enabled = false,
                pos_x = 330,
                pos_y = 310,
                icon_size = 40,
                icon_spacing = 5,
                max_icons = 10,
                lock_position = false,
                show_timer = true,
                timer_font_size = 16,
                timer_color = { 1, 1, 1, 1 },
                show_label = false,
                label_font_size = 14,
                label_color = { 1, 1, 1, 1 },
                tracked_buffs = {}
            }
        }
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
        guild_font_size = 11
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
            sort_vertical = false
        },
        frames = {
            player = {},
            target = {},
            watchtarget = {},
            target_of_target = {}
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

function SettingsDefaults.EnsureDailyAgeDefaults(s)
    if type(s) ~= "table" then
        return
    end
    if type(s.dailyage) ~= "table" then
        s.dailyage = {}
    end
    if s.dailyage.enabled == nil then
        s.dailyage.enabled = false
    end
    if type(s.dailyage.hidden) ~= "table" then
        s.dailyage.hidden = {}
    end
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
            dst.timer_color = {
                tonumber(src.timerTextColor.r) or 1,
                tonumber(src.timerTextColor.g) or 1,
                tonumber(src.timerTextColor.b) or 1,
                tonumber(src.timerTextColor.a) or 1
            }
        end
        if src.showLabel ~= nil then
            dst.show_label = src.showLabel and true or false
        end
        if src.labelFontSize ~= nil then
            dst.label_font_size = tonumber(src.labelFontSize) or dst.label_font_size
        end
        if type(src.labelTextColor) == "table" then
            dst.label_color = {
                tonumber(src.labelTextColor.r) or 1,
                tonumber(src.labelTextColor.g) or 1,
                tonumber(src.labelTextColor.b) or 1,
                tonumber(src.labelTextColor.a) or 1
            }
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

    if cbt.enabled ~= nil then
        s.cooldown_tracker.enabled = cbt.enabled and true or false
    end

    s.cooldown_tracker.migrated_from_cbt = true
    return true
end

function SettingsDefaults.EnsureSettingsDefaultsAndMigrations(s)
    local forceWrite = false
    local legacyRootKeys = {
        "font_size_name",
        "show_mana"
    }

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

    for k, v in pairs(SettingsDefaults.DEFAULT_SETTINGS) do
        if s[k] == nil then
            s[k] = SettingsDefaults.CopyDefaultValue(v)
        end
    end

    for _, key in ipairs(legacyRootKeys) do
        if s[key] ~= nil then
            s[key] = nil
            forceWrite = true
        end
    end

    if type(s.player) ~= "table" then
        s.player = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.player)
    end
    if type(s.target) ~= "table" then
        s.target = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.target)
    end
    if type(s.nameplates) ~= "table" then
        s.nameplates = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.nameplates)
    end
    if type(s.style) ~= "table" then
        s.style = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style)
    end

    local function MigrateLegacyTargetOverlayLayout(styleTable)
        if type(styleTable) ~= "table" then
            return
        end
        local legacyTogglesMissing =
            styleTable.target_guild_visible == nil
            and styleTable.target_class_visible == nil
            and styleTable.target_gearscore_visible == nil
            and styleTable.target_pdef_visible == nil
            and styleTable.target_mdef_visible == nil
        if legacyTogglesMissing and tonumber(styleTable.target_guild_offset_y) == -54 then
            styleTable.target_guild_offset_y = -18
            forceWrite = true
        end
        if styleTable.target_glider_visible ~= nil then
            styleTable.target_glider_visible = nil
            forceWrite = true
        end
        if styleTable.target_glider_color ~= nil then
            styleTable.target_glider_color = nil
            forceWrite = true
        end
    end

    MigrateLegacyTargetOverlayLayout(s.style)

    SettingsDefaults.EnsureCooldownTrackerDefaults(s)
    if SettingsDefaults.TryMigrateCooldownTrackerFromCbt(s) then
        SettingsDefaults.EnsureCooldownTrackerDefaults(s)
        forceWrite = true
    end

    SettingsDefaults.EnsureDailyAgeDefaults(s)

    for k, v in pairs(SettingsDefaults.DEFAULT_SETTINGS.nameplates) do
        if s.nameplates[k] == nil then
            s.nameplates[k] = SettingsDefaults.CopyDefaultValue(v)
        end
    end

    if type(s.nameplates.guild_colors) ~= "table" then
        s.nameplates.guild_colors = {}
    end
    if s.nameplates.click_through_shift ~= nil then
        s.nameplates.click_through_shift = nil
        forceWrite = true
    end
    if s.nameplates.click_through_ctrl ~= nil then
        s.nameplates.click_through_ctrl = nil
        forceWrite = true
    end

    do
        local gc = s.nameplates.guild_colors
        local migrated = false
        local moves = {}
        for k, v in pairs(gc) do
            local kstr = tostring(k or "")
            local norm = NormalizeGuildKey(kstr)
            if norm ~= "" and norm ~= kstr then
                table.insert(moves, { from = k, to = norm, val = v })
            end
        end
        for _, m in ipairs(moves) do
            if gc[m.to] == nil then
                gc[m.to] = m.val
                migrated = true
            end
            gc[m.from] = nil
        end
        if migrated then
            forceWrite = true
        end
    end

    if s.raidframes ~= nil then
        s.raidframes = nil
        forceWrite = true
    end

    for k, v in pairs(SettingsDefaults.DEFAULT_SETTINGS.style) do
        if s.style[k] == nil then
            s.style[k] = SettingsDefaults.CopyDefaultValue(v)
        end
    end

    if type(s.style.buff_windows) ~= "table" then
        s.style.buff_windows = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.buff_windows)
    end
    if type(s.style.aura) ~= "table" then
        s.style.aura = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.aura)
    end
    for k, v in pairs(SettingsDefaults.DEFAULT_SETTINGS.style.buff_windows) do
        if s.style.buff_windows[k] == nil then
            s.style.buff_windows[k] = SettingsDefaults.CopyDefaultValue(v)
        end
    end
    for k, v in pairs(SettingsDefaults.DEFAULT_SETTINGS.style.aura) do
        if s.style.aura[k] == nil then
            s.style.aura[k] = SettingsDefaults.CopyDefaultValue(v)
        end
    end
    if type(s.style.buff_windows.player) ~= "table" then
        s.style.buff_windows.player = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.buff_windows.player)
    end
    if type(s.style.buff_windows.target) ~= "table" then
        s.style.buff_windows.target = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.buff_windows.target)
    end
    if type(s.style.buff_windows.player.buff) ~= "table" then
        s.style.buff_windows.player.buff = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.buff_windows.player.buff)
    end
    if type(s.style.buff_windows.player.debuff) ~= "table" then
        s.style.buff_windows.player.debuff = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.buff_windows.player.debuff)
    end
    if type(s.style.buff_windows.target.buff) ~= "table" then
        s.style.buff_windows.target.buff = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.buff_windows.target.buff)
    end
    if type(s.style.buff_windows.target.debuff) ~= "table" then
        s.style.buff_windows.target.debuff = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.buff_windows.target.debuff)
    end

    if type(s.style.frames) ~= "table" then
        s.style.frames = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.frames)
    end
    if type(s.style.frames.player) ~= "table" then
        s.style.frames.player = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.frames.player)
    end
    if type(s.style.frames.target) ~= "table" then
        s.style.frames.target = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.frames.target)
    end
    if type(s.style.frames.watchtarget) ~= "table" then
        s.style.frames.watchtarget = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.frames.watchtarget)
    end
    if type(s.style.frames.target_of_target) ~= "table" then
        s.style.frames.target_of_target = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.style.frames.target_of_target)
    end
    MigrateLegacyTargetOverlayLayout(s.style.frames.target)
    for k, v in pairs(SettingsDefaults.DEFAULT_SETTINGS.style.buff_windows.player.buff) do
        if s.style.buff_windows.player.buff[k] == nil then
            s.style.buff_windows.player.buff[k] = SettingsDefaults.CopyDefaultValue(v)
        end
    end
    for k, v in pairs(SettingsDefaults.DEFAULT_SETTINGS.style.buff_windows.player.debuff) do
        if s.style.buff_windows.player.debuff[k] == nil then
            s.style.buff_windows.player.debuff[k] = SettingsDefaults.CopyDefaultValue(v)
        end
    end
    for k, v in pairs(SettingsDefaults.DEFAULT_SETTINGS.style.buff_windows.target.buff) do
        if s.style.buff_windows.target.buff[k] == nil then
            s.style.buff_windows.target.buff[k] = SettingsDefaults.CopyDefaultValue(v)
        end
    end
    for k, v in pairs(SettingsDefaults.DEFAULT_SETTINGS.style.buff_windows.target.debuff) do
        if s.style.buff_windows.target.debuff[k] == nil then
            s.style.buff_windows.target.debuff[k] = SettingsDefaults.CopyDefaultValue(v)
        end
    end
    s.style.minimal = nil
    if type(s.role) ~= "table" then
        s.role = SettingsDefaults.DeepCopyTable(SettingsDefaults.DEFAULT_SETTINGS.role)
    end

    api.SaveSettings()
    return forceWrite
end

return SettingsDefaults
