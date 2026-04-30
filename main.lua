local api = require("api")
local Core = api._NuziCore or require("nuzi-core/core")

local Commands = Core.Commands
local Events = Core.Events
local Log = Core.Log
local Require = Core.Require

local bootstrapLogger = Log.Create("Nuzi UI")
local moduleErrors = {}

local function appendModuleErrors(name, errors)
    if type(errors) ~= "table" or #errors == 0 then
        moduleErrors[#moduleErrors + 1] = string.format("%s: unknown load failure", tostring(name))
        return
    end
    moduleErrors[#moduleErrors + 1] = string.format(
        "%s: %s",
        tostring(name),
        Require.DescribeErrors(errors)
    )
end

local modules, failures = Require.AddonSet("nuzi-ui", {
    "ui",
    "settings_page",
    "compat",
    "runtime",
    "settings_store"
})

for name, failure in pairs(failures or {}) do
    appendModuleErrors(name, failure.errors)
end

local UI = modules.ui
local SettingsPage = modules.settings_page
local Compat = modules.compat
local Runtime = modules.runtime
local SettingsStore = modules.settings_store

local NuziUiAddon = {
    name = "Nuzi UI",
    author = "Nuzi",
    version = "4.0.0",
    desc = "Interface overhaul"
}

local logger = Log.Create(NuziUiAddon.name)
local events = Events.Create({
    logger = logger
})

local state = {
    settings = nil,
    last_settings_load_source = "",
    last_settings_load_error = ""
}

local commandRouter = nil

local function modulesReady()
    return UI ~= nil and SettingsPage ~= nil and Compat ~= nil and Runtime ~= nil and SettingsStore ~= nil
end

local function logModuleErrors()
    if #moduleErrors == 0 then
        return
    end
    for _, detail in ipairs(moduleErrors) do
        logger:Err("Module load error: " .. tostring(detail))
    end
end

local function getSettings()
    return state.settings
end

local function applyUiSettings()
    local settings = getSettings()
    if type(settings) ~= "table" then
        return
    end
    if UI ~= nil and UI.ApplySettings ~= nil then
        logger:Try("UI.ApplySettings", UI.ApplySettings, settings)
        return
    end
    if UI ~= nil and UI.Init ~= nil then
        logger:Try("UI.Init(apply)", UI.Init, settings)
    end
end

local function saveSettingsFile()
    local settings = getSettings()
    if type(settings) ~= "table" then
        return false
    end
    return SettingsStore.SaveSettingsFile(settings)
end

local function ensureSettings()
    local settings, meta = SettingsStore.LoadSettings()
    state.settings = settings
    state.last_settings_load_source = type(meta) == "table" and tostring(meta.last_source or "") or ""
    state.last_settings_load_error = type(meta) == "table" and tostring(meta.last_error or "") or ""
    return settings, meta
end

local function saveSettingsBackupFile()
    return SettingsStore.SaveSettingsBackupFile(getSettings())
end

local function logBackupList(maxN)
    SettingsStore.LogBackupList(maxN)
end

local function importSettingsBackupFile(arg)
    local settings = getSettings()
    if type(settings) ~= "table" then
        return false, "settings not initialized"
    end

    local ok, err = SettingsStore.ImportSettingsBackupFile(settings, arg)
    if not ok then
        return ok, err
    end

    saveSettingsFile()
    applyUiSettings()
    if SettingsPage ~= nil and SettingsPage.open ~= nil then
        logger:Try("SettingsPage.open(import)", SettingsPage.open)
    end
    return true, ""
end

local function reinitializeModules()
    local settings = getSettings()
    if type(settings) ~= "table" then
        return
    end

    if UI ~= nil and UI.UnLoad ~= nil then
        logger:Try("UI.UnLoad(reinit)", UI.UnLoad)
    end

    if SettingsPage ~= nil and SettingsPage.Unload ~= nil then
        logger:Try("SettingsPage.Unload(reinit)", SettingsPage.Unload)
    end

    if SettingsPage ~= nil and SettingsPage.init ~= nil then
        logger:Try("SettingsPage.init", SettingsPage.init, settings, saveSettingsFile, applyUiSettings, {
            backup_settings = saveSettingsBackupFile,
            import_settings = importSettingsBackupFile
        })
    end

    if UI ~= nil and UI.Init ~= nil then
        logger:Try("UI.Init", UI.Init, settings)
    end
end

local function logRuntimeSummary()
    if Compat == nil then
        return
    end
    local runtime = Compat.Get()
    local caps = runtime.caps or {}
    logger:Info(string.format(
        "Runtime nameplates=%s sliders=%s anchor=%s targeting=%s",
        caps.nameplates_supported and "yes" or "no",
        caps.slider_factory and "yes" or "no",
        caps.nametag_anchor and "nametag" or (caps.screen_position and "screen" or "none"),
        tostring(caps.targeting_mode or "unknown")
    ))
    for _, warning in ipairs(runtime.warnings or {}) do
        logger:Info(tostring(warning))
    end
    for _, blocker in ipairs(runtime.blockers or {}) do
        logger:Err(tostring(blocker))
    end
end

local function onUpdate(dt)
    if UI == nil or UI.OnUpdate == nil then
        return
    end
    logger:Try("UI.OnUpdate", UI.OnUpdate, dt)
end

local function onUiReloaded()
    if Compat ~= nil then
        Compat.Probe(true)
        logRuntimeSummary()
    end
    reinitializeModules()
end

local function getPlayerName()
    if Runtime ~= nil and Runtime.GetPlayerName ~= nil then
        return tostring(Runtime.GetPlayerName() or "")
    end
    return ""
end

local function handleUiCommand(ctx)
    local settings = getSettings()
    local subcommand = string.lower(tostring(ctx.subcommand or ""))

    if ctx.rest == "" then
        if type(settings) ~= "table" then
            return false, "settings not initialized"
        end
        settings.enabled = not (settings.enabled and true or false)
        saveSettingsFile()
        if UI ~= nil and UI.SetEnabled ~= nil then
            logger:Try("UI.SetEnabled", UI.SetEnabled, settings.enabled)
        end
        return true
    end

    if subcommand == "settings" then
        if SettingsPage ~= nil and SettingsPage.toggle ~= nil then
            logger:Try("SettingsPage.toggle", SettingsPage.toggle)
        end
        return true
    end

    if subcommand == "backup" then
        local ok, result = saveSettingsBackupFile()
        if ok then
            logger:Info("Backup saved: " .. tostring(result))
        else
            logger:Err("Backup failed: " .. tostring(result))
        end
        return true
    end

    if subcommand == "backups" then
        logBackupList(tonumber(ctx.args[2]))
        logger:Info("Usage: !nui import <n>")
        return true
    end

    if subcommand == "import" then
        local ok, err = importSettingsBackupFile(ctx.args[2])
        if ok then
            logger:Info("Imported backup")
        else
            logger:Err("Import failed: " .. tostring(err))
        end
        return true
    end

    return false, "unhandled"
end

local function buildCommandRouter()
    local router = Commands.CreateRouter({
        logger = logger,
        get_player_name = getPlayerName,
        local_only = true
    })
    router:Add("!nui", handleUiCommand)
    router:AddAlias("!pui", "!nui")
    return router
end

local function onChatMessage(...)
    if commandRouter == nil then
        return false
    end
    return commandRouter:Handle(...)
end

local function onLoad()
    if not modulesReady() then
        logModuleErrors()
        bootstrapLogger:Err("Failed to load one or more modules.")
        return
    end

    logModuleErrors()
    ensureSettings()
    if Compat ~= nil then
        Compat.Probe(true)
        logRuntimeSummary()
    end
    reinitializeModules()
    commandRouter = buildCommandRouter()

    events:OnSafe("UPDATE", "UPDATE", onUpdate)
    events:OnSafe("CHAT_MESSAGE", "CHAT_MESSAGE", onChatMessage)
    events:OptionalOnSafe("COMMUNITY_CHAT_MESSAGE", "COMMUNITY_CHAT_MESSAGE", onChatMessage)
    events:OnSafe("UI_RELOADED", "UI_RELOADED", onUiReloaded)

    logger:Info("Loaded. !nui toggles overlays; !nui settings opens the settings window. !pui still works.")
end

local function onUnload()
    events:ClearAll()
    commandRouter = nil

    if UI ~= nil and UI.UnLoad ~= nil then
        logger:Try("UI.UnLoad(unload)", UI.UnLoad)
    end

    if SettingsPage ~= nil and SettingsPage.Unload ~= nil then
        logger:Try("SettingsPage.Unload(unload)", SettingsPage.Unload)
    end
end

NuziUiAddon.OnLoad = onLoad
NuziUiAddon.OnUnload = onUnload

return NuziUiAddon
