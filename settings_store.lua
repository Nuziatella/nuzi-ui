local api = require("api")
local SettingsDefaults = require("nuzi-ui/settings_defaults")

local Store = {}

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

local ADDONS_BASE_PATH = nil
pcall(function()
    if type(api) == "table" and type(api.baseDir) == "string" and api.baseDir ~= "" then
        ADDONS_BASE_PATH = string.gsub(api.baseDir, "\\", "/")
        return
    end
    if type(debug) == "table" and type(debug.getinfo) == "function" then
        local info = debug.getinfo(1, "S")
        local src = type(info) == "table" and tostring(info.source or "") or ""
        if string.sub(src, 1, 1) == "@" then
            src = string.sub(src, 2)
        end
        src = string.gsub(src, "\\", "/")
        local dir = string.match(src, "^(.*)/[^/]+$")
        if dir ~= nil then
            local base = string.match(dir, "^(.*)/[^/]+$")
            if base ~= nil and base ~= "" then
                ADDONS_BASE_PATH = base
            end
        end
    end
end)

local function ReadRawFileFallback(path)
    if ADDONS_BASE_PATH == nil or type(io) ~= "table" or type(io.open) ~= "function" then
        return nil, false, false
    end
    local full = tostring(ADDONS_BASE_PATH) .. "/" .. tostring(path)
    full = string.gsub(full, "/+", "/")
    local file = nil
    local ok = pcall(function()
        file = io.open(full, "rb")
    end)
    if not ok or file == nil then
        return nil, false, true
    end
    local contents = nil
    pcall(function()
        contents = file:read("*a")
    end)
    pcall(function()
        file:close()
    end)
    if type(contents) ~= "string" or contents == "" then
        return nil, true, true
    end
    return contents, true, true
end

function Store.ReadSettingsFromFile(path)
    if api.File == nil or api.File.Read == nil then
        return nil, "file:unavailable", ""
    end

    local ok, res = pcall(function()
        return api.File:Read(path)
    end)
    if not ok then
        return nil, "file:read_error", tostring(res)
    end

    if res == nil then
        local raw, exists, probed = ReadRawFileFallback(path)
        if type(raw) == "string" then
            return nil, "file:legacy_text", "legacy text settings are no longer executed; resave via api.File:Write"
        elseif probed and exists then
            return nil, "file:unreadable", ""
        elseif probed then
            return nil, "file:missing", ""
        else
            return nil, "file:nil", ""
        end
    end
    if type(res) == "table" then
        return res, "file:table", ""
    end
    if type(res) ~= "string" then
        return nil, "file:unknown_type", ""
    end
    return nil, "file:string", "string settings are unsupported; expected api.File:Read to deserialize a table"
end

function Store.LoadSettings()
    local runtime = api.GetSettings("nuzi-ui")
    if type(runtime) ~= "table" then
        runtime = api.GetSettings(Store.LEGACY_ADDON_ID)
    end
    if type(runtime) ~= "table" then
        runtime = {}
    end

    local settings = runtime
    local meta = {
        file_missing = false,
        file_unreadable = false,
        loaded_legacy_file = false,
        last_source = "",
        last_error = ""
    }

    local fileSettings = nil
    do
        local parsed, source, err = Store.ReadSettingsFromFile(Store.SETTINGS_FILE_PATH)
        meta.last_source = source
        meta.last_error = err
        if parsed == nil then
            if source == "file:missing" then
                meta.file_missing = true
                local legacyParsed, legacySource, legacyErr = Store.ReadSettingsFromFile(Store.LEGACY_LOCAL_SETTINGS_FILE_PATH)
                if type(legacyParsed) ~= "table" then
                    legacyParsed, legacySource, legacyErr = Store.ReadSettingsFromFile(Store.LEGACY_SETTINGS_FILE_PATH)
                end
                if type(legacyParsed) == "table" then
                    fileSettings = legacyParsed
                    meta.loaded_legacy_file = true
                    meta.last_source = legacySource
                    meta.last_error = legacyErr
                end
            elseif source == "file:unreadable" then
                meta.file_unreadable = true
                api.Log:Err("[Nuzi UI] Failed to deserialize " .. Store.SETTINGS_FILE_PATH .. " (file exists but was not readable)")
            elseif source == "file:read_error" then
                api.Log:Err("[Nuzi UI] Failed to read " .. Store.SETTINGS_FILE_PATH .. ": " .. tostring(err))
            elseif source == "file:nil" then
                api.Log:Err("[Nuzi UI] Failed to read " .. Store.SETTINGS_FILE_PATH .. " (api.File:Read returned nil and raw fallback unavailable)")
            elseif source == "file:legacy_text" or source == "file:string" then
                api.Log:Err("[Nuzi UI] Failed to load " .. Store.SETTINGS_FILE_PATH .. " because it was a raw string file; Nuzi UI now expects api.File:Read to deserialize a table")
            elseif source == "file:raw" then
                api.Log:Err("[Nuzi UI] Failed to parse " .. Store.SETTINGS_FILE_PATH .. " (error=" .. tostring(err) .. ")")
            end
        else
            fileSettings = parsed
        end
    end

    if type(fileSettings) == "table" then
        SettingsDefaults.MergeInto(settings, fileSettings)
    end

    local forceWrite = SettingsDefaults.EnsureSettingsDefaultsAndMigrations(settings)
    local shouldWrite = false
    if meta.file_missing or meta.loaded_legacy_file then
        shouldWrite = true
    elseif not meta.file_unreadable and type(fileSettings) == "table" and forceWrite then
        shouldWrite = true
    end

    if shouldWrite then
        Store.SaveSettingsFile(settings)
    end

    return settings, meta
end

function Store.SaveSettingsFile(settings)
    api.SaveSettings()
    if api.File ~= nil and api.File.Write ~= nil and type(settings) == "table" then
        SettingsDefaults.EnsureSettingsDefaultsAndMigrations(settings)
        pcall(function()
            api.File:Write(Store.SETTINGS_FILE_PATH, settings)
        end)
    end
end

function Store.SaveSettingsBackupFile(settings)
    if api.File == nil or api.File.Write == nil or type(settings) ~= "table" then
        return false, "api.File:Write unavailable"
    end
    SettingsDefaults.EnsureSettingsDefaultsAndMigrations(settings)

    local ts = nil
    pcall(function()
        if api.Time ~= nil and api.Time.GetLocalTime ~= nil then
            ts = api.Time:GetLocalTime()
        end
    end)
    if ts == nil then
        ts = tostring(math.random(1000000000, 9999999999))
    end
    ts = tostring(ts)

    local backupPath = string.format("%s/settings_%s.txt", Store.SETTINGS_BACKUP_DIR, ts)
    local ok, err = pcall(function()
        api.File:Write(backupPath, settings)
    end)
    if not ok then
        backupPath = string.format("nuzi-ui/.data/settings_backup_%s.txt", ts)
        ok, err = pcall(function()
            api.File:Write(backupPath, settings)
        end)
        if not ok then
            return false, tostring(err)
        end
    end

    local idx = nil
    pcall(function()
        idx = Store.ReadSettingsFromFile(Store.SETTINGS_BACKUP_INDEX_FILE_PATH)
    end)
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.LEGACY_LOCAL_SETTINGS_BACKUP_INDEX_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.LEGACY_LOCAL_SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" then
        idx = { version = 1, backups = {} }
    end
    if type(idx.backups) ~= "table" then
        idx.backups = {}
    end

    table.insert(idx.backups, 1, { path = backupPath, timestamp = ts })
    while #idx.backups > 50 do
        table.remove(idx.backups)
    end

    pcall(function()
        api.File:Write(Store.SETTINGS_BACKUP_INDEX_FILE_PATH, idx)
    end)
    pcall(function()
        local parsed2, source2 = Store.ReadSettingsFromFile(Store.SETTINGS_BACKUP_INDEX_FILE_PATH)
        if parsed2 == nil and tostring(source2) ~= "file:table" then
            api.File:Write(Store.SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH, idx)
        end
    end)

    pcall(function()
        local legacyParsed, legacySource = Store.ReadSettingsFromFile(Store.LEGACY_LOCAL_SETTINGS_BACKUP_FILE_PATH)
        if legacyParsed == nil and tostring(legacySource) == "file:missing" then
            api.File:Write(Store.LEGACY_LOCAL_SETTINGS_BACKUP_FILE_PATH, settings)
        end
    end)

    api.Log:Info("[Nuzi UI] Backup saved: " .. tostring(backupPath))
    return true, backupPath
end

function Store.ResolveBackupPathFromArg(arg)
    local idx = nil
    pcall(function()
        idx = Store.ReadSettingsFromFile(Store.SETTINGS_BACKUP_INDEX_FILE_PATH)
    end)
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.LEGACY_LOCAL_SETTINGS_BACKUP_INDEX_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.LEGACY_LOCAL_SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.LEGACY_SETTINGS_BACKUP_INDEX_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.LEGACY_SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" or type(idx.backups) ~= "table" then
        idx = nil
    end

    local raw = tostring(arg or "")
    raw = string.match(raw, "^%s*(.-)%s*$") or raw
    if raw == "" then
        if idx ~= nil and idx.backups[1] ~= nil and type(idx.backups[1].path) == "string" then
            return idx.backups[1].path
        end
        return Store.SETTINGS_BACKUP_FILE_PATH or Store.LEGACY_LOCAL_SETTINGS_BACKUP_FILE_PATH or Store.LEGACY_SETTINGS_BACKUP_FILE_PATH
    end

    local n = tonumber(raw)
    if n ~= nil and idx ~= nil and idx.backups[n] ~= nil and type(idx.backups[n].path) == "string" then
        return idx.backups[n].path
    end

    if string.find(raw, "nuzi-ui/", 1, true) == 1 or string.find(raw, "polar-ui/", 1, true) == 1 then
        return raw
    end

    if idx ~= nil then
        for _, e in ipairs(idx.backups) do
            if type(e) == "table" and tostring(e.path) == raw then
                return raw
            end
        end
    end
    return nil
end

function Store.LogBackupList(maxN)
    local limit = tonumber(maxN) or 10
    if limit < 1 then
        limit = 1
    end
    if limit > 50 then
        limit = 50
    end

    local idx = nil
    pcall(function()
        idx = Store.ReadSettingsFromFile(Store.SETTINGS_BACKUP_INDEX_FILE_PATH)
    end)
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.LEGACY_LOCAL_SETTINGS_BACKUP_INDEX_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.LEGACY_LOCAL_SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.LEGACY_SETTINGS_BACKUP_INDEX_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" then
        pcall(function()
            idx = Store.ReadSettingsFromFile(Store.LEGACY_SETTINGS_BACKUP_INDEX_FALLBACK_FILE_PATH)
        end)
    end
    if type(idx) ~= "table" or type(idx.backups) ~= "table" or #idx.backups == 0 then
        api.Log:Info("[Nuzi UI] No backups found.")
        return
    end

    api.Log:Info("[Nuzi UI] Backups:")
    local n = 0
    for i, e in ipairs(idx.backups) do
        if n >= limit then
            break
        end
        if type(e) == "table" and type(e.path) == "string" then
            api.Log:Info(string.format("[Nuzi UI]  %d) %s", i, e.path))
            n = n + 1
        end
    end
end

function Store.ImportSettingsBackupFile(settings, arg)
    if type(settings) ~= "table" then
        return false, "settings not initialized"
    end

    local backupPath = Store.ResolveBackupPathFromArg(arg)
    if backupPath == nil then
        return false, "no backups found (use Backup first or run !nui backups)"
    end

    local parsed, source, err = Store.ReadSettingsFromFile(backupPath)
    if type(parsed) ~= "table" then
        if err == "" then
            err = "no backup found"
        end
        return false, tostring(source) .. ":" .. tostring(err)
    end

    for k in pairs(settings) do
        settings[k] = nil
    end
    SettingsDefaults.MergeInto(settings, parsed)
    SettingsDefaults.EnsureSettingsDefaultsAndMigrations(settings)

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
        api.Log:Info(string.format(
            "[Nuzi UI] Imported backup (%s): player=(%s,%s) target=(%s,%s) guild_colors=%s",
            tostring(backupPath),
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
