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
Store.MOUNT_GLIDER_DEVICES_FILE_PATH = "nuzi-ui/.data/mount_glider_devices.txt"
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

local function ensureDirectory(path)
    local dir = string.match(tostring(path or ""), "^(.*)[/\\][^/\\]+$")
    if dir == nil or dir == "" or type(os) ~= "table" or type(os.execute) ~= "function" then
        return
    end
    dir = string.gsub(dir, "\\", "/")
    dir = string.gsub(dir, '"', '""')
    pcall(function()
        os.execute('mkdir "' .. dir .. '" >nul 2>nul')
    end)
end

local function ensureParentDirectory(path)
    if type(path) ~= "string" or path == "" then
        return
    end
    ensureDirectory(path)
    if Settings.GetFullPath ~= nil then
        ensureDirectory(Settings.GetFullPath(path))
    end
end

local function ensureDataDirectories(includeBackups)
    ensureParentDirectory(Store.SETTINGS_FILE_PATH)
    ensureParentDirectory(Store.SETTINGS_BACKUP_FILE_PATH)
    ensureParentDirectory(Store.MOUNT_GLIDER_DEVICES_FILE_PATH)
    if includeBackups then
        ensureParentDirectory(Store.SETTINGS_BACKUP_INDEX_FILE_PATH)
    end
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

local function copyTable(value)
    return SettingsDefaults.CopyDefaultValue(value)
end

local function getMountGliderSettings(settings)
    if type(settings) ~= "table" then
        return nil
    end
    if type(settings.mount_glider) ~= "table" then
        settings.mount_glider = {}
    end
    if type(settings.mount_glider.learned_mounts) ~= "table" then
        settings.mount_glider.learned_mounts = {}
    end
    if type(settings.mount_glider.learned_gliders) ~= "table" then
        settings.mount_glider.learned_gliders = {}
    end
    return settings.mount_glider
end

local function tableHasEntries(value)
    if type(value) ~= "table" then
        return false
    end
    for _ in pairs(value) do
        return true
    end
    return false
end

local function integerString(value)
    local number = tonumber(value)
    if number == nil then
        return nil
    end
    return string.format("%.0f", math.floor(number + 0.5))
end

local function trailingNumber(value)
    local number = tonumber(string.match(tostring(value or ""), "_(%d+)$"))
    if number == nil then
        return nil
    end
    return math.floor(number + 0.5)
end

local function normalizeIdList(values)
    if type(values) ~= "table" then
        return nil
    end
    local out = {}
    for _, value in ipairs(values) do
        local text = integerString(value)
        if text ~= nil then
            out[#out + 1] = text
        end
    end
    return out
end

local function normalizeLearnedAbilityIds(ability)
    if type(ability) ~= "table" then
        return
    end
    local keyId = trailingNumber(ability.key)
    local isBuff = tostring(ability.icon_type or "") == "buff"
        or ability.spell_id ~= nil
        or ability.buff_id ~= nil
        or type(ability.buff_ids) == "table"
    if isBuff and keyId ~= nil then
        ability.spell_id = integerString(keyId)
        ability.buff_ids = { integerString(keyId) }
        ability.icon_id = integerString(keyId)
        ability.icon_type = "buff"
        ability.exact_spell_id = true
    else
        if ability.spell_id ~= nil then
            ability.spell_id = integerString(ability.spell_id)
        end
        if ability.buff_id ~= nil then
            ability.buff_id = integerString(ability.buff_id)
        end
        if type(ability.buff_ids) == "table" then
            ability.buff_ids = normalizeIdList(ability.buff_ids)
        end
        if ability.icon_id ~= nil then
            ability.icon_id = integerString(ability.icon_id)
        end
    end
    if ability.mount_mana_spent ~= nil then
        ability.mount_mana_spent = integerString(ability.mount_mana_spent)
    end
end

local function normalizeLearnedDeviceIds(device)
    if type(device) ~= "table" then
        return
    end
    local itemId = tonumber(string.match(tostring(device.key or ""), "^learned_glider_(%d+)$"))
    if itemId ~= nil then
        device.item_ids = { integerString(itemId) }
    elseif type(device.item_ids) == "table" then
        device.item_ids = normalizeIdList(device.item_ids)
    end
    if device.item_id ~= nil then
        device.item_id = integerString(device.item_id)
    end
    for _, ability in ipairs(device.abilities or {}) do
        normalizeLearnedAbilityIds(ability)
    end
end

local function normalizeMountGliderDeviceIds(settings)
    local cfg = getMountGliderSettings(settings)
    if type(cfg) ~= "table" then
        return
    end
    for _, listKey in ipairs({ "learned_mounts", "learned_gliders" }) do
        for _, device in ipairs(type(cfg[listKey]) == "table" and cfg[listKey] or {}) do
            normalizeLearnedDeviceIds(device)
        end
    end
end

local function buildMountGliderDevices(settings)
    local cfg = getMountGliderSettings(settings)
    if type(cfg) ~= "table" then
        return {
            learned_mounts = {},
            learned_gliders = {}
        }
    end
    return {
        learned_mounts = copyTable(cfg.learned_mounts),
        learned_gliders = copyTable(cfg.learned_gliders)
    }
end

local function hasMountGliderDevices(settings)
    local cfg = getMountGliderSettings(settings)
    return type(cfg) == "table"
        and (tableHasEntries(cfg.learned_mounts) or tableHasEntries(cfg.learned_gliders))
end

function Store.GetStore()
    return store
end

function Store.ReadSettingsFromFile(path)
    return Settings.ReadFlexibleTable(path, readOptions())
end

function Store.ReadMountGliderDevicesFile()
    return Settings.ReadFlexibleTable(Store.MOUNT_GLIDER_DEVICES_FILE_PATH, readOptions())
end

function Store.LoadMountGliderDevices(settings)
    if type(settings) ~= "table" then
        return false
    end

    local devices, source, err = Store.ReadMountGliderDevicesFile()
    if type(devices) == "table" then
        local fileHasDevices = tableHasEntries(devices.learned_mounts) or tableHasEntries(devices.learned_gliders)
        if fileHasDevices or not hasMountGliderDevices(settings) then
            local cfg = getMountGliderSettings(settings)
            cfg.learned_mounts = type(devices.learned_mounts) == "table" and copyTable(devices.learned_mounts) or {}
            cfg.learned_gliders = type(devices.learned_gliders) == "table" and copyTable(devices.learned_gliders) or {}
            return true, tostring(source or "")
        end
    end

    if hasMountGliderDevices(settings) then
        Store.SaveMountGliderDevices(settings)
    end
    return false, tostring(err or "")
end

function Store.SaveMountGliderDevices(settings)
    if type(settings) ~= "table" then
        return false
    end
    ensureParentDirectory(Store.MOUNT_GLIDER_DEVICES_FILE_PATH)
    normalizeMountGliderDeviceIds(settings)
    local ok = Settings.WriteTable(
        Store.MOUNT_GLIDER_DEVICES_FILE_PATH,
        buildMountGliderDevices(settings),
        "serialized_then_flat"
    )
    if not ok then
        logError("Failed to save mount/glider devices.")
    end
    return ok and true or false
end

function Store.LoadSettings()
    local settings, meta = store:Load()
    meta = type(meta) == "table" and meta or {}

    if type(meta.preferred_reason) == "string" and meta.preferred_reason ~= "" then
        logInfo("Recovered settings from mirror backup because " .. tostring(meta.preferred_reason))
    elseif meta.migrated and type(meta.source_path) == "string" and meta.source_path ~= "" then
        logInfo("Recovered settings from " .. tostring(meta.source_path))
    end

    Store.LoadMountGliderDevices(settings)
    normalizeMountGliderDeviceIds(settings)

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
    ensureDataDirectories(false)
    normalizeSettings(settings)
    normalizeMountGliderDeviceIds(settings)
    ensureStoreSettings(settings)
    local ok = store:Save()
    if not ok then
        logError("Failed to save settings.")
    end
    local devicesOk = Store.SaveMountGliderDevices(settings)
    return ok and devicesOk and true or false
end

function Store.SaveSettingsBackupFile(settings)
    if type(settings) ~= "table" then
        return false, "settings not initialized"
    end
    ensureDataDirectories(true)
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
