local api = require("api")

local Learning = {}

local BUFF_UNITS = { "playerpet", "playerpet1", "playerpet2", "slave", "player" }
local MOUNT_UNITS = { "playerpet1", "playerpet", "slave", "playerpet2" }
local SCAN_INTERVAL_MS = 250
local MAX_CAPTURE_MS = 90000
local DEFAULT_GLIDER_COOLDOWN_MS = 60000
local DEFAULT_MOUNT_COOLDOWN_MS = 30000
local MIN_MOUNT_MANA_SPEND = 10

local session = nil

local function safeCall(fn)
    local ok, a, b, c = pcall(fn)
    if ok then
        return a, b, c
    end
    return nil
end

local function trim(value)
    local text = tostring(value or "")
    return string.match(text, "^%s*(.-)%s*$") or text
end

local function formatId(value)
    local number = tonumber(value)
    if number == nil then
        return trim(value)
    end
    return string.format("%.0f", number)
end

local function normalizeMs(value)
    local number = tonumber(value)
    if number == nil then
        return nil
    end
    if number > 0 and number < 5 then
        return number * 1000
    end
    return number
end

local function cleanTooltipText(value)
    local text = tostring(value or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "|ni;", "")
    return text
end

local function extractSpecialSkillNames(value)
    if type(value) ~= "table" then
        return {}
    end
    local description = cleanTooltipText(value.description or value.desc or value.tooltip or "")
    local skillText = string.match(description, "Special Skill:%s*([^\r\n]+)")
        or string.match(description, "Special Skills:%s*([^\r\n]+)")
    if skillText == nil then
        return {}
    end

    local names = {}
    for name in string.gmatch(skillText, "([^,]+)") do
        name = trim(name)
        if name ~= "" then
            names[#names + 1] = name
        end
    end
    return names
end

local function getDisplayName(value)
    if type(value) ~= "table" then
        return ""
    end
    for _, key in ipairs({ "name", "itemName", "item_name", "title", "buffName", "skillName" }) do
        local text = trim(value[key])
        if text ~= "" then
            return text
        end
    end
    return ""
end

local function getIconPath(value)
    if type(value) ~= "table" then
        return ""
    end
    for _, key in ipairs({ "iconPath", "icon_path", "icon", "path", "texturePath", "texture" }) do
        local text = trim(value[key])
        if text ~= "" then
            return text
        end
    end
    return ""
end

local function getEquippedBackpack()
    local slot = type(EQUIP_SLOT) == "table" and EQUIP_SLOT.BACKPACK or nil
    if slot == nil or api == nil or api.Equipment == nil or api.Equipment.GetEquippedItemTooltipInfo == nil then
        return nil
    end
    local info = safeCall(function()
        return api.Equipment:GetEquippedItemTooltipInfo(slot)
    end)
    if type(info) ~= "table" then
        return nil
    end
    local itemType = tonumber(info.itemType or info.item_type)
    local name = getDisplayName(info)
    if itemType == nil or name == "" then
        return nil
    end
    return {
        item_type = math.floor(itemType + 0.5),
        name = name,
        path = tostring(info.path or info.iconPath or ""),
        slot_type = tostring(info.slotType or ""),
        special_skill_names = extractSpecialSkillNames(info)
    }
end

local function getBagCapacity()
    if api == nil or api.Bag == nil or api.Bag.Capacity == nil then
        return 0
    end
    return tonumber(safeCall(function()
        return api.Bag:Capacity()
    end)) or 0
end

local function getBagItem(index)
    if api == nil or api.Bag == nil or api.Bag.GetBagItemInfo == nil then
        return nil
    end
    local info = safeCall(function()
        return api.Bag:GetBagItemInfo(1, index)
    end)
    return type(info) == "table" and info or nil
end

local function findBagItemByName(name)
    name = string.lower(trim(name))
    if name == "" then
        return nil
    end
    local capacity = getBagCapacity()
    for index = 1, capacity do
        local info = getBagItem(index)
        if type(info) == "table" and string.lower(getDisplayName(info)) == name then
            local itemType = tonumber(info.itemType or info.item_type)
            return {
                item_type = itemType ~= nil and math.floor(itemType + 0.5) or nil,
                path = getIconPath(info),
                name = getDisplayName(info)
            }
        end
    end
    return nil
end

local function validUnitId(value)
    local text = tostring(value or "")
    return value ~= nil and text ~= "" and text ~= "0"
end

local function getUnitId(unit)
    if api == nil or api.Unit == nil or api.Unit.GetUnitId == nil then
        return nil
    end
    local id = safeCall(function()
        return api.Unit:GetUnitId(unit)
    end)
    if validUnitId(id) then
        return id
    end
    return nil
end

local function getUnitName(unit)
    if api == nil or api.Unit == nil or api.Unit.UnitName == nil then
        return ""
    end
    return trim(safeCall(function()
        return api.Unit:UnitName(unit)
    end))
end

local function getUnitInfo(unit)
    if api == nil or api.Unit == nil then
        return nil
    end
    if api.Unit.UnitInfo ~= nil then
        local info = safeCall(function()
            return api.Unit:UnitInfo(unit)
        end)
        if type(info) == "table" then
            return info
        end
    end
    local unitId = getUnitId(unit)
    if unitId ~= nil and api.Unit.GetUnitInfoById ~= nil then
        local info = safeCall(function()
            return api.Unit:GetUnitInfoById(unitId)
        end)
        if type(info) == "table" then
            return info
        end
    end
    return nil
end

local function getUnitMana(unit)
    if api == nil or api.Unit == nil or api.Unit.UnitMana == nil then
        return nil
    end
    return tonumber(safeCall(function()
        return api.Unit:UnitMana(unit)
    end))
end

local function getSummonedMount()
    local seen = {}
    for _, unit in ipairs(MOUNT_UNITS) do
        local id = getUnitId(unit)
        if id ~= nil and seen[tostring(id)] ~= true then
            seen[tostring(id)] = true
            local name = getUnitName(unit)
            if name == "" then
                name = "Summoned Mount"
            end
            local info = getUnitInfo(unit)
            return {
                unit = unit,
                unit_id = id,
                name = name,
                path = getIconPath(info),
                mana = getUnitMana(unit)
            }
        end
    end
    return nil
end

local function getBuffId(buff)
    if type(buff) ~= "table" then
        return nil
    end
    local id = tonumber(buff.buff_id or buff.buffId or buff.id or buff.spellId or buff.spell_id)
    if id == nil then
        return nil
    end
    return math.floor(id + 0.5)
end

local function getBuffCount(unit)
    if api == nil or api.Unit == nil or api.Unit.UnitBuffCount == nil then
        return 0
    end
    return tonumber(safeCall(function()
        return api.Unit:UnitBuffCount(unit)
    end)) or 0
end

local function getBuff(unit, index)
    if api == nil or api.Unit == nil or api.Unit.UnitBuff == nil then
        return nil
    end
    local buff = safeCall(function()
        return api.Unit:UnitBuff(unit, index)
    end)
    return type(buff) == "table" and buff or nil
end

local function getBuffTooltip(id)
    if api == nil or api.Ability == nil or api.Ability.GetBuffTooltip == nil then
        return nil
    end
    local tooltip = safeCall(function()
        return api.Ability:GetBuffTooltip(id, 1)
    end)
    return type(tooltip) == "table" and tooltip or nil
end

local function scanBuffs()
    local out = {}
    for _, unit in ipairs(BUFF_UNITS) do
        local count = getBuffCount(unit)
        for index = 1, count do
            local buff = getBuff(unit, index)
            local id = getBuffId(buff)
            if id ~= nil then
                out[#out + 1] = {
                    id = id,
                    buff = buff,
                    unit = unit,
                    time_left_ms = normalizeMs(buff.timeLeft or buff.leftTime or buff.remainTime)
                }
            end
        end
    end
    return out
end

local function makeBaseline()
    local baseline = {}
    for _, entry in ipairs(scanBuffs()) do
        baseline[entry.id] = true
    end
    return baseline
end

local function makeAbilityKey(name, id)
    local key = string.lower(trim(name))
    key = string.gsub(key, "%s+", "_")
    key = string.gsub(key, "[^%w_]", "")
    if key == "" then
        key = "ability_" .. formatId(id)
    end
    return key .. "_" .. formatId(id)
end

local function makeDeviceKey(prefix, name, id)
    local key = string.lower(trim(name))
    key = string.gsub(key, "%s+", "_")
    key = string.gsub(key, "[^%w_]", "")
    if key == "" then
        key = "device"
    end
    if id ~= nil then
        return prefix .. "_" .. key .. "_" .. formatId(id)
    end
    return prefix .. "_" .. key
end

local function summarizeAbilities(abilities)
    local labels = {}
    for _, ability in ipairs(abilities or {}) do
        labels[#labels + 1] = tostring(ability.label or ability.key)
    end
    if #labels == 0 then
        return "No abilities captured yet."
    end
    return "Captured: " .. table.concat(labels, ", ")
end

local function getAbilityKeys(abilities)
    local keys = {}
    for _, ability in ipairs(abilities or {}) do
        if type(ability) == "table" and tostring(ability.key or "") ~= "" then
            keys[#keys + 1] = ability.key
        end
    end
    return keys
end

local function getKind(itemName)
    local lower = string.lower(tostring(itemName or ""))
    if string.find(lower, "magithopter", 1, true) ~= nil then
        return "Magithopter"
    end
    return "Glider"
end

local function isDeviceAura(entry)
    if session == nil or type(entry) ~= "table" then
        return false
    end
    local id = tonumber(entry.id)
    if id == nil then
        return false
    end
    if session.baseline[id] == true or session.captured[id] == true then
        return false
    end
    local timeLeft = tonumber(entry.time_left_ms)
    if timeLeft == nil or timeLeft <= 0 or timeLeft > MAX_CAPTURE_MS then
        return false
    end
    local tooltip = getBuffTooltip(id)
    local name = getDisplayName(tooltip)
    if name == "" then
        name = getDisplayName(entry.buff)
    end
    if string.lower(name) == string.lower(session.item_name) then
        return false
    end
    entry.tooltip = tooltip
    entry.name = name ~= "" and name or ("Ability " .. formatId(id))
    return true
end

local abilitiesMatch
local mergeAbility

local function updateStatus(text)
    if session ~= nil then
        session.status = tostring(text or "")
        session.revision = (tonumber(session.revision) or 0) + 1
    end
end

local function captureAbility(entry)
    local id = tonumber(entry.id)
    if id == nil or session == nil then
        return
    end
    id = math.floor(id + 0.5)
    session.captured[id] = true
    local iconPath = ""
    if type(entry.tooltip) == "table" then
        iconPath = tostring(entry.tooltip.iconPath or entry.tooltip.path or "")
    end
    if iconPath == "" and type(entry.buff) == "table" then
        iconPath = tostring(entry.buff.iconPath or entry.buff.path or "")
    end
    session.abilities[#session.abilities + 1] = {
        key = makeAbilityKey(entry.name, id),
        label = entry.name,
        spell_id = id,
        buff_ids = { id },
        duration_ms = session.mode == "mount" and DEFAULT_MOUNT_COOLDOWN_MS or DEFAULT_GLIDER_COOLDOWN_MS,
        icon_type = "buff",
        icon_id = id,
        icon_path = iconPath,
        exact_spell_id = true,
        learned = true,
        observed_uptime_ms = tonumber(entry.time_left_ms)
    }
    if session.mode == "mount" then
        updateStatus(summarizeAbilities(session.abilities) .. ". Keep using buff skills, or click End Mount.")
    else
        updateStatus(summarizeAbilities(session.abilities) .. ". Use another ability, or click End Adding.")
    end
    return true
end

local function mergeSessionAbility(ability)
    if session == nil or type(ability) ~= "table" then
        return false
    end
    for _, existing in ipairs(session.abilities or {}) do
        if abilitiesMatch(existing, ability) then
            mergeAbility(existing, ability)
            return true
        end
    end
    session.abilities[#session.abilities + 1] = ability
    return true
end

local function captureManaAbility(spent, labelOverride)
    spent = tonumber(spent)
    if spent == nil or session == nil or spent < MIN_MOUNT_MANA_SPEND then
        return false
    end
    spent = math.floor(spent + 0.5)
    local label = trim(labelOverride or session.pending_ability_name)
    if label == "" then
        return false
    end
    local ability = {
        key = makeAbilityKey(label, spent),
        label = label,
        mount_mana_spent = spent,
        duration_ms = DEFAULT_MOUNT_COOLDOWN_MS,
        icon_type = "mount",
        icon_path = tostring(session.mount_icon_path or ""),
        learned = true
    }
    session.captured_mana[spent] = true
    mergeSessionAbility(ability)
    session.pending_ability_name = ""
    updateStatus(summarizeAbilities(session.abilities) .. ". Enter another name and click Add No-Buff Skill, or click End Mount.")
    return true
end

abilitiesMatch = function(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    if tostring(left.key or "") ~= "" and left.key == right.key then
        return true
    end
    if tonumber(left.spell_id) ~= nil and tonumber(left.spell_id) == tonumber(right.spell_id) then
        return true
    end
    if tonumber(left.mount_mana_spent) ~= nil
        and tonumber(left.mount_mana_spent) == tonumber(right.mount_mana_spent) then
        return true
    end
    if tonumber(left.spell_id) == nil
        and tonumber(right.spell_id) == nil
        and trim(left.label) ~= ""
        and string.lower(trim(left.label)) == string.lower(trim(right.label)) then
        return true
    end
    return false
end

mergeAbility = function(existing, incoming)
    local durationMs = tonumber(existing.duration_ms)
    for key, value in pairs(incoming) do
        existing[key] = value
    end
    if durationMs ~= nil then
        existing.duration_ms = durationMs
    end
end

local function mergeDevice(existing, incoming)
    existing.name = incoming.name
    existing.kind = incoming.kind
    existing.summary = incoming.summary
    existing.learned = true
    if type(existing.icon_path) ~= "string" or existing.icon_path == "" then
        existing.icon_path = incoming.icon_path
    end
    if type(existing.item_ids) ~= "table" or #existing.item_ids == 0 then
        existing.item_ids = incoming.item_ids
    end
    if type(existing.abilities) ~= "table" then
        existing.abilities = {}
    end
    for _, incomingAbility in ipairs(incoming.abilities or {}) do
        local matched = nil
        for _, existingAbility in ipairs(existing.abilities) do
            if abilitiesMatch(existingAbility, incomingAbility) then
                matched = existingAbility
                break
            end
        end
        if matched ~= nil then
            mergeAbility(matched, incomingAbility)
        else
            existing.abilities[#existing.abilities + 1] = incomingAbility
        end
    end
    existing.summary = summarizeAbilities(existing.abilities):gsub("^Captured:%s*", "")
end

local function saveLearnedDevice(cfg, device, listKey)
    if type(cfg) ~= "table" or type(device) ~= "table" then
        return
    end
    listKey = tostring(listKey or "learned_gliders")
    if type(cfg[listKey]) ~= "table" then
        cfg[listKey] = {}
    end
    for index, existing in ipairs(cfg[listKey]) do
        local sameKey = type(existing) == "table" and existing.key == device.key
        local sameMountName = type(existing) == "table"
            and listKey == "learned_mounts"
            and tostring(existing.name or "") ~= ""
            and existing.name == device.name
        if sameKey or sameMountName then
            device.key = existing.key
            mergeDevice(existing, device)
            return
        end
    end
    cfg[listKey][#cfg[listKey] + 1] = device
end

local function copyValue(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for key, item in pairs(value) do
        out[key] = copyValue(item)
    end
    return out
end

local function findExistingMount(cfg, name)
    name = string.lower(trim(name))
    if type(cfg) ~= "table" or name == "" then
        return nil
    end
    for _, mount in ipairs(type(cfg.learned_mounts) == "table" and cfg.learned_mounts or {}) do
        if type(mount) == "table" and string.lower(trim(mount.name)) == name then
            return mount
        end
    end
    return nil
end

function Learning.Start(settings)
    local item = getEquippedBackpack()
    if item == nil then
        session = nil
        return false, "Equip a glider or magithopter in your back slot first."
    end

    session = {
        active = true,
        mode = "glider",
        item_type = item.item_type,
        item_name = item.name,
        item_path = item.path,
        kind = getKind(item.name),
        special_skill_names = item.special_skill_names,
        baseline = makeBaseline(),
        captured = {},
        captured_mana = {},
        abilities = {},
        elapsed_ms = 0,
        scan_ms = 0,
        revision = 0,
        status = ""
    }

    local prompt = "Learning " .. item.name .. ". Use each ability you want to track, then click End Adding."
    if #item.special_skill_names > 0 then
        prompt = prompt .. " Tooltip lists: " .. table.concat(item.special_skill_names, ", ") .. "."
    end
    updateStatus(prompt)
    return true, session.status
end

function Learning.StartMount(settings)
    local mount = getSummonedMount()
    if mount == nil then
        session = nil
        return false, "Summon your mount first."
    end
    local bagItem = findBagItemByName(mount.name)
    local iconPath = bagItem ~= nil and tostring(bagItem.path or "") or ""
    if iconPath == "" then
        iconPath = tostring(mount.path or "")
    end
    local existing = findExistingMount(settings, mount.name)
    local existingAbilities = {}
    if type(existing) == "table" then
        for _, ability in ipairs(existing.abilities or {}) do
            existingAbilities[#existingAbilities + 1] = copyValue(ability)
        end
        if iconPath == "" then
            iconPath = tostring(existing.icon_path or "")
        end
    end
    if session ~= nil
        and session.active == true
        and session.mode == "mount"
        and tostring(session.mount_unit_id or "") == tostring(mount.unit_id or "") then
        if iconPath ~= "" then
            session.mount_icon_path = iconPath
        end
        if bagItem ~= nil and tonumber(bagItem.item_type) ~= nil then
            session.mount_item_type = math.floor(tonumber(bagItem.item_type) + 0.5)
        end
        updateStatus("Learning " .. session.item_name .. ". Click Add Buff Skills or enter a skill name for Add No-Buff Skill.")
        return true, session.status
    end

    session = {
        active = true,
        mode = "mount",
        item_name = mount.name,
        mount_unit = mount.unit,
        mount_unit_id = mount.unit_id,
        mount_icon_path = iconPath,
        mount_item_type = bagItem ~= nil and bagItem.item_type or nil,
        pending_ability_name = "",
        mount_buff_scan = false,
        last_mount_mana = mount.mana,
        kind = "Mount",
        special_skill_names = {},
        baseline = makeBaseline(),
        captured = {},
        captured_mana = {},
        abilities = existingAbilities,
        elapsed_ms = 0,
        scan_ms = 0,
        revision = 0,
        status = ""
    }

    updateStatus("Learning " .. mount.name .. ". Click Add Buff Skills or enter a skill name for Add No-Buff Skill.")
    return true, session.status
end

function Learning.AddMountBuffSkills(settings)
    local mount = getSummonedMount()
    if mount == nil then
        return false, "Summon your mount first."
    end
    if session == nil or session.active ~= true or session.mode ~= "mount" then
        Learning.StartMount(settings)
    end
    if session == nil
        or session.active ~= true
        or session.mode ~= "mount"
        or tostring(session.mount_unit_id or "") ~= tostring(mount.unit_id or "") then
        return false, "Click Add Mount for the summoned mount first."
    end

    session.baseline = makeBaseline()
    session.pending_ability_name = ""
    session.mount_buff_scan = true
    updateStatus("Use each buff skill now. I will capture each new buff separately.")
    return true, session.status
end

function Learning.AddMountSkill(settings, abilityName, manaCost)
    abilityName = trim(abilityName)
    if abilityName == "" then
        return false, "Enter the mount skill name first."
    end
    local mount = getSummonedMount()
    if mount == nil then
        return false, "Summon your mount first."
    end
    if session == nil or session.active ~= true or session.mode ~= "mount" then
        Learning.StartMount(settings)
    end
    if session == nil
        or session.active ~= true
        or session.mode ~= "mount"
        or tostring(session.mount_unit_id or "") ~= tostring(mount.unit_id or "") then
        return false, "Click Add Mount for the summoned mount first."
    end

    local manualCost = tonumber(manaCost)
    if manualCost ~= nil and manualCost >= MIN_MOUNT_MANA_SPEND then
        session.mount_buff_scan = false
        captureManaAbility(manualCost, abilityName)
        return true, session.status
    end

    session.pending_ability_name = abilityName
    session.mount_buff_scan = false
    session.last_mount_mana = mount.mana
    updateStatus("Use " .. abilityName .. " now. I will capture the mount mana spend.")
    return true, session.status
end

function Learning.Finish(cfg)
    if session == nil or session.active ~= true or session.mode ~= "glider" then
        return false, "Click Add Glider/Magithopter first."
    end
    if #session.abilities == 0 then
        return false, "No abilities captured yet. Use an ability, then click End Adding."
    end

    local key = "learned_glider_" .. formatId(session.item_type)
    local device = {
        key = key,
        name = session.item_name,
        kind = session.kind,
        summary = summarizeAbilities(session.abilities):gsub("^Captured:%s*", ""),
        learned = true,
        icon_path = session.item_path,
        item_ids = { session.item_type },
        abilities = session.abilities
    }
    saveLearnedDevice(cfg, device, "learned_gliders")
    session.active = false
    local message = "Added " .. session.item_name .. " with " .. tostring(#session.abilities) .. " tracked "
        .. (#session.abilities == 1 and "ability." or "abilities.")
    local abilityKeys = getAbilityKeys(session.abilities)
    session = nil
    return true, message, device.key, abilityKeys
end

function Learning.FinishMount(cfg)
    if session == nil or session.active ~= true or session.mode ~= "mount" then
        return false, "Click Add Mount first."
    end
    if #session.abilities == 0 then
        return false, "No abilities captured yet. Use an ability, then click End Mount."
    end

    local key = makeDeviceKey("learned_mount", session.item_name, session.mount_unit_id)
    local device = {
        key = key,
        name = session.item_name,
        kind = "Mount",
        summary = summarizeAbilities(session.abilities):gsub("^Captured:%s*", ""),
        learned = true,
        icon_path = session.mount_icon_path,
        item_ids = tonumber(session.mount_item_type) ~= nil and { session.mount_item_type } or nil,
        abilities = session.abilities
    }
    saveLearnedDevice(cfg, device, "learned_mounts")
    session.active = false
    local message = "Added " .. session.item_name .. " with " .. tostring(#session.abilities) .. " tracked "
        .. (#session.abilities == 1 and "ability." or "abilities.")
    local abilityKeys = getAbilityKeys(session.abilities)
    session = nil
    return true, message, device.key, abilityKeys
end

function Learning.Cancel()
    session = nil
end

function Learning.OnUpdate(dt)
    if session == nil or session.active ~= true then
        return false
    end
    session.elapsed_ms = (tonumber(session.elapsed_ms) or 0) + (tonumber(dt) or 0)
    session.scan_ms = (tonumber(session.scan_ms) or 0) + (tonumber(dt) or 0)
    if session.scan_ms < SCAN_INTERVAL_MS then
        return false
    end
    session.scan_ms = 0

    local mountMana = nil
    if session.mode == "mount" then
        local mount = getSummonedMount()
        if mount ~= nil and tostring(mount.unit_id or "") == tostring(session.mount_unit_id or "") then
            mountMana = mount.mana
        end
    end

    if session.mode ~= "mount" or session.mount_buff_scan == true then
        local captured = false
        for _, entry in ipairs(scanBuffs()) do
            if isDeviceAura(entry) then
                captureAbility(entry)
                captured = true
            end
        end
        if captured then
            if mountMana ~= nil then
                session.last_mount_mana = mountMana
            end
            return true
        end
    end

    if session.mode == "mount" and mountMana ~= nil then
        local spent = (tonumber(session.last_mount_mana) or mountMana) - mountMana
        session.last_mount_mana = mountMana
        if captureManaAbility(spent) then
            return true
        end
    end
    return false
end

function Learning.GetStatus()
    if session == nil or session.status == "" then
        return "Click Add Glider/Magithopter while equipped, or Add Mount while mounted."
    end
    return session.status
end

return Learning
