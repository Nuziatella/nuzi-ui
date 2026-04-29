local SettingsCatalog = {}

SettingsCatalog.PAGES = {
    {
        id = "general",
        label = "General",
        title = "General",
        summary = "Core addon toggles and shared runtime behavior."
    },
    {
        id = "repair",
        label = "UI Repair",
        title = "UI Repair",
        summary = "Screen scale diagnostics and safe layout reset tools."
    },
    {
        id = "npc",
        label = "NPC",
        title = "NPC",
        summary = "Stock unit-frame art, boss target decorations, target distance, and grade-star placement."
    },
    {
        id = "text",
        label = "Text",
        title = "Text",
        summary = "Name, level, role, guild, and number formatting."
    },
    {
        id = "bars",
        label = "Bars",
        title = "Bars",
        summary = "Frame sizing, alpha, bar colors, textures, and value placement."
    },
    {
        id = "castbar",
        label = "Cast Bar",
        title = "Cast Bar",
        summary = "Movable player cast bar with customizable colors, text, and textures."
    },
    {
        id = "travel",
        label = "Travel",
        title = "Travel Speed",
        summary = "Movable speed meter for vehicles, mounts, gliders, and on-foot travel."
    },
    {
        id = "loadouts",
        label = "Loadouts",
        title = "Gear Loadouts",
        summary = "Per-character gear loadout bar with a drag/drop equipment editor."
    },
    {
        id = "auras",
        label = "Auras",
        title = "Auras",
        summary = "Aura windows, icon layout, and buff or debuff anchor controls."
    },
    {
        id = "plates",
        label = "Nameplates",
        title = "Nameplates",
        summary = "Visibility rules, offsets, debuff icons, colors, and runtime nameplate behavior."
    },
    {
        id = "cooldown",
        label = "Cooldowns",
        title = "Cooldown Tracker",
        summary = "Tracked buff and debuff icons for player, target, pet, watchtarget, and target of target."
    }
}

function SettingsCatalog.GetPage(pageId)
    for _, page in ipairs(SettingsCatalog.PAGES) do
        if page.id == pageId then
            return page
        end
    end
    return nil
end

return SettingsCatalog
