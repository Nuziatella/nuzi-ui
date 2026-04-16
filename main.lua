local api = require("api")
local SafeRequire = require("nuzi-ui/safe_require")

local UI = SafeRequire("nuzi-ui/ui", "nuzi-ui.ui")
local SettingsPage = SafeRequire("nuzi-ui/settings_page", "nuzi-ui.settings_page")
local Compat = SafeRequire("nuzi-ui/compat", "nuzi-ui.compat")
local Runtime = SafeRequire("nuzi-ui/runtime", "nuzi-ui.runtime")
local SettingsStore = SafeRequire("nuzi-ui/settings_store", "nuzi-ui.settings_store")

local SaveSettingsFile = nil

local PolarUiAddon = {
    name = "Nuzi UI",
    author = "Nuzi",
    version = "2.1.2",
    desc = "Interface overhaul"
}

local function EnsureSettings()
    local meta = nil
    settings, meta = SettingsStore.LoadSettings()
    lastSettingsLoadSource = type(meta) == "table" and tostring(meta.last_source or "") or ""
    lastSettingsLoadError = type(meta) == "table" and tostring(meta.last_error or "") or ""
end

local function SaveSettingsBackupFile()
    return SettingsStore.SaveSettingsBackupFile(settings)
end

local function ResolveBackupPathFromArg(arg)
    return SettingsStore.ResolveBackupPathFromArg(arg)
end

local function LogBackupList(maxN)
    SettingsStore.LogBackupList(maxN)
end

local function ImportSettingsBackupFile(arg)
    local ok, err = SettingsStore.ImportSettingsBackupFile(settings, arg)
    if not ok then
        return ok, err
    end
    if type(SaveSettingsFile) == "function" then
        SaveSettingsFile()
    end
    if UI ~= nil and UI.ApplySettings ~= nil then
        pcall(function()
            UI.ApplySettings(settings)
        end)
    elseif UI ~= nil and UI.Init ~= nil then
        pcall(function()
            UI.Init(settings)
        end)
    end
    if SettingsPage ~= nil and SettingsPage.open ~= nil then
        pcall(function()
            SettingsPage.open()
        end)
    end
    return true, ""
end

SaveSettingsFile = function()
    SettingsStore.SaveSettingsFile(settings)
end

local function OnUpdate(dt)
    if UI == nil or UI.OnUpdate == nil then
        return
    end

    local ok, err = pcall(function()
        UI.OnUpdate(dt)
    end)
    if not ok then
        api.Log:Err("[Nuzi UI] UI.OnUpdate failed: " .. tostring(err))
    end
end

local function ReinitializeModules()
    if type(settings) ~= "table" then
        return
    end

    if UI ~= nil and UI.UnLoad ~= nil then
        pcall(function()
            UI.UnLoad()
        end)
    end

    if SettingsPage ~= nil and SettingsPage.Unload ~= nil then
        pcall(function()
            SettingsPage.Unload()
        end)
    end

    if SettingsPage ~= nil and SettingsPage.init ~= nil then
        local ok, err = pcall(function()
            SettingsPage.init(settings, SaveSettingsFile, function()
                if UI ~= nil and UI.ApplySettings ~= nil then
                    UI.ApplySettings(settings)
                elseif UI ~= nil and UI.Init ~= nil then
                    UI.Init(settings)
                end
            end, {
                backup_settings = SaveSettingsBackupFile,
                import_settings = ImportSettingsBackupFile
            })
        end)
        if not ok and api ~= nil and api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi UI] SettingsPage.init failed: " .. tostring(err))
        end
    end

    if UI ~= nil and UI.Init ~= nil then
        local ok, err = pcall(function()
            UI.Init(settings)
        end)
        if not ok then
            api.Log:Err("[Nuzi UI] UI.Init failed: " .. tostring(err))
        end
    end
end

local HandleChatCommand

local function LogRuntimeSummary()
    if Compat == nil or api == nil or api.Log == nil or api.Log.Info == nil then
        return
    end
    local runtime = Compat.Get()
    local caps = runtime.caps or {}
    api.Log:Info(string.format(
        "[Nuzi UI] Runtime nameplates=%s sliders=%s anchor=%s targeting=%s",
        caps.nameplates_supported and "yes" or "no",
        caps.slider_factory and "yes" or "no",
        caps.nametag_anchor and "nametag" or (caps.screen_position and "screen" or "none"),
        tostring(caps.targeting_mode or "unknown")
    ))
    for _, warning in ipairs(runtime.warnings or {}) do
        api.Log:Info("[Nuzi UI] " .. tostring(warning))
    end
    for _, blocker in ipairs(runtime.blockers or {}) do
        if api.Log.Err ~= nil then
            api.Log:Err("[Nuzi UI] " .. tostring(blocker))
        end
    end
end

local function OnCommunityChatMessage(...)
    HandleChatCommand(...)
end

local function OnUiReloaded()
    if Compat ~= nil then
        Compat.Probe(true)
        LogRuntimeSummary()
    end
    ReinitializeModules()
end

HandleChatCommand = function(arg1, arg2, arg3, arg4, arg5)
    local message = ""
    local senderName = ""
    local senderUnit = ""

    if type(arg5) == "string" then
        message = arg5
    elseif type(arg3) == "string" then
        message = arg3
    elseif type(arg1) == "string" then
        message = arg1
    end

    if type(arg4) == "string" then
        senderName = arg4
    elseif type(arg2) == "string" then
        senderName = arg2
    end
    if type(arg1) == "string" then
        senderUnit = arg1
    end

    message = tostring(message or "")
    message = string.match(message, "^%s*(.-)%s*$") or message

    if message == "" then
        return
    end

    senderName = tostring(senderName or "")
    senderUnit = tostring(senderUnit or "")

    local isLocalCommand = false
    if senderUnit == "player" then
        isLocalCommand = true
    else
        local myName = Runtime ~= nil and Runtime.GetPlayerName() or ""
        if myName ~= "" and senderName == myName then
            isLocalCommand = true
        end
    end

    local cmd, rest = string.match(message, "^(%S+)%s*(.-)$")
    cmd = tostring(cmd or "")
    rest = tostring(rest or "")
    local sub = string.match(rest, "^(%S+)")
    sub = tostring(sub or "")

    local isUiCommand = cmd == "!pui" or cmd == "!nui"

    if isUiCommand and not isLocalCommand then
        return
    end

    if isUiCommand and rest == "" then
        if type(settings) ~= "table" then
            return
        end
        settings.enabled = not settings.enabled
        SaveSettingsFile()
        if UI ~= nil and UI.SetEnabled ~= nil then
            UI.SetEnabled(settings.enabled)
        end
        return
    end

    if isUiCommand and sub == "settings" then
        if SettingsPage ~= nil and SettingsPage.toggle ~= nil then
            pcall(function()
                SettingsPage.toggle()
            end)
        end
        return
    end

    if isUiCommand and sub == "backup" then
        local ok, res = SaveSettingsBackupFile()
        if ok then
            api.Log:Info("[Nuzi UI] Backup saved: " .. tostring(res))
        else
            api.Log:Err("[Nuzi UI] Backup failed: " .. tostring(res))
        end
        return
    end

    if isUiCommand and sub == "backups" then
        local _, argN = string.match(rest, "^(%S+)%s*(.-)$")
        argN = tostring(argN or "")
        LogBackupList(tonumber(argN))
        api.Log:Info("[Nuzi UI] Usage: !nui import <n>")
        return
    end

    if isUiCommand and sub == "import" then
        local _, argN = string.match(rest, "^(%S+)%s*(.-)$")
        argN = tostring(argN or "")
        local ok, err = ImportSettingsBackupFile(argN)
        if ok then
            api.Log:Info("[Nuzi UI] Imported backup")
        else
            api.Log:Err("[Nuzi UI] Import failed: " .. tostring(err))
        end
        return
    end

end

local function OnLoad()
    EnsureSettings()
    if Compat ~= nil then
        Compat.Probe(true)
        LogRuntimeSummary()
    end
    ReinitializeModules()

    api.On("UPDATE", OnUpdate)
    api.On("CHAT_MESSAGE", HandleChatCommand)
    pcall(function()
        api.On("COMMUNITY_CHAT_MESSAGE", OnCommunityChatMessage)
    end)
    api.On("UI_RELOADED", OnUiReloaded)

    api.Log:Info("[Nuzi UI] Loaded. !nui toggles overlays; !nui settings opens the settings window. !pui still works.")
end

local function OnUnload()
    api.On("UPDATE", function() end)
    api.On("CHAT_MESSAGE", function() end)
    pcall(function()
        api.On("COMMUNITY_CHAT_MESSAGE", function() end)
    end)
    api.On("UI_RELOADED", function() end)

    if UI ~= nil and UI.UnLoad ~= nil then
        pcall(function()
            UI.UnLoad()
        end)
    end

    if SettingsPage ~= nil and SettingsPage.Unload ~= nil then
        pcall(function()
            SettingsPage.Unload()
        end)
    end
end

PolarUiAddon.OnLoad = OnLoad
PolarUiAddon.OnUnload = OnUnload

return PolarUiAddon
