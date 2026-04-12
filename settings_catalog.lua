local SettingsCatalog = {}

SettingsCatalog.PAGES = {
    {
        id = "general",
        label = "General",
        title = "General",
        summary = "Core addon toggles and shared runtime behavior."
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
        id = "auras",
        label = "Auras",
        title = "Auras",
        summary = "Aura windows, icon layout, and buff or debuff anchor controls."
    },
    {
        id = "plates",
        label = "Nameplates",
        title = "Nameplates",
        summary = "Visibility rules, offsets, colors, and runtime nameplate behavior."
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
