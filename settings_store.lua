local api = require("api")
local Core = api._NuziCore or require("nuzi-core/core")
local SettingsDefaults = require("nuzi-ui/settings_defaults")

local Settings = Core.Settings

local Store = {}

Store.ADDON_ID = "nuzi-ui"
Store.SETTINGS_FILE_PATH = "nuzi-ui/.data/settings.txt"
Store.SETTINGS_BACKUP_FILE_PATH = "nuzi-ui/.data/settings_backup.txt"
Store.SETTINGS_BACKUP_INDEX_FILE_PATH = "nuzi-ui/.data/backups/index.txt"
Store.SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH = "nuzi-ui/.data/settings_backup_index.txt"
Store.SETTINGS_BACKUP_DIR = "nuzi-ui/.data/backups"
Store.LEGACY_LOCAL_SETTINGS_FILE_PATH = "nuzi-ui/settings.txt"
Store.LEGACY_LOCAL_SETTINGS_BACKUP_FILE_PATH = "nuzi-ui/settings_backup.txt"
Store.LEGACY_LOCAL_SETTINGS_BACKUP_INDEX_FILE_PATH = "nuzi-ui/backups/index.txt"
Store.LEGACY_LOCAL_SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH = "nuzi-ui/settings_backup_index.txt"
Store.LEGACY_ADDON_ID = "polar-ui"
Store.LEGACY_SETTINGS_FILE_PATH = "polar-ui/settings.txt"
Store.LEGACY_SETTINGS_BACKUP_FILE_PATH = "polar-ui/settings_backup.txt"
Store.LEGACY_SETTINGS_BACKUP_INDEX_FILE_PATH = "polar-ui/backups/index.txt"
Store.LEGACY_SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH = "polar-ui/settings_backup_index.txt"

local function logInfo(message)
    if api ~= nil and api.Log ~= nil and api.Log.Info ~= nil then
        pcall(function()
            api.Log:Info("[Nuzi UI] " .. tostring(message or ""))
        end)
    end
end

local function logError(message)
    if api ~= nil and api.Log ~= nil and api.Log.Err ~= nil then
        pcall(function()
            api.Log:Err("[Nuzi UI] " .. tostring(message or ""))
        end)
    end
end

local function normalizeSettings(settings)
    return SettingsDefaults.EnsureSettingsDefaultsAndMigrations(settings)
end

local store = Settings.CreateStore({
    addon_id = Store.ADDON_ID,
    legacy_addon_ids = {
        Store.LEGACY_ADDON_ID
    },
    settings_file_path = Store.SETTINGS_FILE_PATH,
    legacy_settings_file_path = Store.LEGACY_LOCAL_SETTINGS_FILE_PATH,
    fallback_paths = {
        Store.SETTINGS_BACKUP_FILE_PATH,
        Store.LEGACY_LOCAL_SETTINGS_BACKUP_FILE_PATH,
        Store.LEGACY_SETTINGS_FILE_PATH,
        Store.LEGACY_SETTINGS_BACKUP_FILE_PATH
    },
    defaults = SettingsDefaults.DEFAULT_SETTINGS,
    read_mode = "serialized_then_flat",
    write_mode = "serialized_then_flat",
    read_raw_text_fallback = true,
    write_mirror_paths = {
        Store.SETTINGS_BACKUP_FILE_PATH
    },
    prefer_richer_candidate_paths = {
        Store.SETTINGS_BACKUP_FILE_PATH
    },
    richer_preference = {
        bonus_paths = {
            "nameplates.guild_colors"
        },
        min_score_delta = 40,
        min_score_ratio = 1.35,
        bonus_min_score_delta = 20,
        bonus_min_score_ratio = 1.10
    },
    backups = {
        read_mode = "serialized_then_flat",
        write_mode = "serialized_then_flat",
        read_raw_text_fallback = true,
        backup_dir = Store.SETTINGS_BACKUP_DIR,
        backup_prefix = "settings",
        index_file_path = Store.SETTINGS_BACKUP_INDEX_FILE_PATH,
        index_fallback_file_path = Store.SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH,
        legacy_index_paths = {
            Store.LEGACY_LOCAL_SETTINGS_BACKUP_INDEX_FILE_PATH,
            Store.LEGACY_LOCAL_SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH,
            Store.LEGACY_SETTINGS_BACKUP_INDEX_FILE_PATH,
            Store.LEGACY_SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH
        },
        latest_backup_file_path = Store.SETTINGS_BACKUP_FILE_PATH,
        legacy_latest_paths = {
            Store.LEGACY_LOCAL_SETTINGS_BACKUP_FILE_PATH,
            Store.LEGACY_SETTINGS_BACKUP_FILE_PATH
        },
        max_backups = 50
    },
    log_name = "Nuzi UI",
    normalize = function(settings)
        return normalizeSettings(settings)
    end
})

Store.store = store

local function readOptions()
    return {
        mode = "serialized_then_flat",
        raw_text_fallback = true
    }
end

local function ensureStoreSettings(settings)
    if type(settings) == "table" then
        store.settings = settings
    end
    return store.settings
end

function Store.GetStore()
    return store
end

function Store.ReadSettingsFromFile(path)
    return Settings.ReadFlexibleTable(path, readOptions())
end

function Store.LoadSettings()
    local settings, meta = store:Load()
    meta = type(meta) == "table" and meta or {}

    if type(meta.preferred_reason) == "string" and meta.preferred_reason ~= "" then
        logInfo("Recovered settings from mirror backup because " .. tostring(meta.preferred_reason))
    elseif meta.migrated and type(meta.source_path) == "string" and meta.source_path ~= "" then
        logInfo("Recovered settings from " .. tostring(meta.source_path))
    end

    return settings, {
        file_missing = meta.has_primary == false,
        file_unreadable = tostring(meta.last_source or "") == "file:unreadable" and not meta.migrated,
        loaded_legacy_file = meta.migrated and true or false,
        last_source = tostring(meta.last_source or ""),
        last_error = tostring(meta.last_error or ""),
        source_path = meta.source_path,
        source_kind = meta.source_kind,
        preferred_reason = meta.preferred_reason
    }
end

function Store.SaveSettingsFile(settings)
    if type(settings) ~= "table" then
        return false
    end
    normalizeSettings(settings)
    ensureStoreSettings(settings)
    local ok = store:Save()
    if not ok then
        logError("Failed to save settings.")
    end
    return ok and true or false
end

function Store.SaveSettingsBackupFile(settings)
    if type(settings) ~= "table" then
        return false, "settings not initialized"
    end
    normalizeSettings(settings)
    ensureStoreSettings(settings)
    local ok, result = store:SaveBackup()
    if ok then
        logInfo("Backup saved: " .. tostring(result))
        return true, result
    end
    return false, tostring(result)
end

function Store.ResolveBackupPathFromArg(arg)
    return store:ResolveBackupPath(arg)
end

function Store.LogBackupList(maxN)
    local limit = tonumber(maxN) or 10
    if limit < 1 then
        limit = 1
    end
    if limit > 50 then
        limit = 50
    end

    local items = store:ListBackups(limit)
    if type(items) ~= "table" or #items == 0 then
        logInfo("No backups found.")
        return
    end

    logInfo("Backups:")
    for _, item in ipairs(items) do
        logInfo(string.format(" %d) %s", tonumber(item.index) or 0, tostring(item.path or "")))
    end
end

function Store.ImportSettingsBackupFile(settings, arg)
    if type(settings) ~= "table" then
        return false, "settings not initialized"
    end

    local parsed, sourcePath = store.backups:Import(arg)
    if type(parsed) ~= "table" then
        return false, tostring(sourcePath)
    end

    for key in pairs(settings) do
        settings[key] = nil
    end
    SettingsDefaults.MergeInto(settings, parsed)
    normalizeSettings(settings)
    ensureStoreSettings(settings)

    pcall(function()
        local px = type(parsed.player) == "table" and parsed.player.x or nil
        local py = type(parsed.player) == "table" and parsed.player.y or nil
        local tx = type(parsed.target) == "table" and parsed.target.x or nil
        local ty = type(parsed.target) == "table" and parsed.target.y or nil
        local gcCount = 0
        if type(parsed.nameplates) == "table" and type(parsed.nameplates.guild_colors) == "table" then
            for _ in pairs(parsed.nameplates.guild_colors) do
                gcCount = gcCount + 1
            end
        end
        logInfo(string.format(
            "Imported backup (%s): player=(%s,%s) target=(%s,%s) guild_colors=%s",
            tostring(sourcePath),
            tostring(px),
            tostring(py),
            tostring(tx),
            tostring(ty),
            tostring(gcCount)
        ))
    end)

    return true, ""
end

return Store
