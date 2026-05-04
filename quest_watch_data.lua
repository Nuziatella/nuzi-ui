local QuestWatchData = {}

QuestWatchData.GROUPS = {
    { key = "crimson_omens_1", category = "Crimson Rift", label = "Crimson Omens 1", ids = { 2941 } },
    { key = "crimson_omens_2", category = "Crimson Rift", label = "Crimson Omens 2", ids = { 2942 } },
    { key = "crimson_omens_3", category = "Crimson Rift", label = "Crimson Omens 3", ids = { 2943 } },
    { key = "crimson_defeat_hounds", category = "Crimson Rift", label = "Defeat Hounds", ids = { 5886 } },
    { key = "crimson_defeat_anthalon", category = "Crimson Rift", label = "Defeat Anthalon", ids = { 5885 } },

    { key = "grimghast_construction", category = "Grimghast Rift", label = "Construction", ids = { 5142, 5157 } },
    { key = "grimghast_tide_1", category = "Grimghast Rift", label = "Halting Crimson Tide 1", ids = { 5143 } },
    { key = "grimghast_tide_2", category = "Grimghast Rift", label = "Halting Crimson Tide 2", ids = { 5144 } },
    { key = "grimghast_nightmare_1", category = "Grimghast Rift", label = "Defeat Nightmare 1", ids = { 7648 } },
    { key = "grimghast_nightmare_2", category = "Grimghast Rift", label = "Defeat Nightmare 2", ids = { 7649 } },

    { key = "whalesong_wave_1", category = "Whalesong Siege", label = "Wave 1", ids = { 8602, 8609, 8610, 8611 } },
    { key = "whalesong_wave_2", category = "Whalesong Siege", label = "Wave 2", ids = { 8603, 8612, 8613, 8614 } },
    { key = "whalesong_wave_3", category = "Whalesong Siege", label = "Wave 3", ids = { 8604, 8615, 8616, 8617 } },
    { key = "whalesong_siege_stage", category = "Whalesong Siege", label = "Siege Stage", ids = { 8637, 8638, 8639, 8640 } },
    { key = "whalesong_boss", category = "Whalesong Siege", label = "Boss Kill", ids = { 8605, 8606, 8607, 8608 } },

    { key = "aegis_wave_1", category = "Aegis Island", label = "Wave 1", ids = { 8623, 8624, 8625, 8626 } },
    { key = "aegis_wave_2", category = "Aegis Island", label = "Wave 2", ids = { 8627, 8628, 8629, 8630 } },
    { key = "aegis_wave_3", category = "Aegis Island", label = "Wave 3", ids = { 8631, 8632, 8633, 8634 } },
    { key = "aegis_stage", category = "Aegis Island", label = "Island Stage", ids = { 8641, 8642, 8643, 8644 } },
    { key = "aegis_boss", category = "Aegis Island", label = "Boss Kill", ids = { 8618, 8619, 8620, 8621 } },

    { key = "luscas_awakening", category = "Luscas Awakening", label = "Lusca Awakening", ids = { 5765 } },

    { key = "abyssal_becoming_seaknight", category = "Abyssal Attack", label = "Becoming a Seaknight", ids = { 6973, 6974, 6975, 6976 } },
    { key = "abyssal_stopping_doomsday", category = "Abyssal Attack", label = "Stopping Doomsday", ids = { 6791 } },

    { key = "prophecy_jola", category = "The Prophecy", label = "Jola", ids = { 5971 } },
    { key = "prophecy_meina", category = "The Prophecy", label = "Meina", ids = { 5969 } },
    { key = "prophecy_glenn", category = "The Prophecy", label = "Glenn", ids = { 5970 } },
    { key = "prophecy_extra", category = "The Prophecy", label = "Prophecy Quest", ids = { 5972 } },

    { key = "ocean_sea_trade", category = "Ocean Gilda", label = "Enemies of Sea Trade", ids = { 6797 } },
    { key = "ocean_ghosts_depths", category = "Ocean Gilda", label = "Ghosts from the Depths", ids = { 6792 } },
    { key = "ocean_malice", category = "Ocean Gilda", label = "Calming the Ocean's Malice", ids = { 6793 } },
    { key = "ocean_ghost_ships", category = "Ocean Gilda", label = "Ghost Ships of Delphinad", ids = { 6798 } },

    { key = "prestige_construction_1", category = "Prestige", label = "Grand Construction 1", ids = { 7606, 7609 } },
    { key = "prestige_construction_2", category = "Prestige", label = "Grand Construction 2", ids = { 7607, 7610 } },
    { key = "prestige_construction_3", category = "Prestige", label = "Grand Construction 3", ids = { 7608, 7611 } },
    { key = "prestige_pirate_politics", category = "Prestige", label = "Pirate Politics", ids = { 7616 } },

    { key = "library_f1_p1", category = "Library", label = "Floor 1 Part 1", ids = { 6095 } },
    { key = "library_f1_p2", category = "Library", label = "Floor 1 Part 2", ids = { 6096 } },
    { key = "library_f1_p3", category = "Library", label = "Floor 1 Part 3", ids = { 6430 } },
    { key = "library_f2_p1", category = "Library", label = "Floor 2 Part 1", ids = { 6118 } },
    { key = "library_f2_p2", category = "Library", label = "Floor 2 Part 2", ids = { 6119 } },
    { key = "library_f2_p3", category = "Library", label = "Floor 2 Part 3", ids = { 6431 } },
    { key = "library_f3_p1", category = "Library", label = "Floor 3 Part 1", ids = { 6141 } },
    { key = "library_f3_p2", category = "Library", label = "Floor 3 Part 2", ids = { 6142 } },
    { key = "library_f3_p3", category = "Library", label = "Floor 3 Part 3", ids = { 6432 } },
    { key = "library_agent_p1", category = "Library", label = "Ayanad Agent Part 1", ids = { 6637 } },
    { key = "library_agent_p2", category = "Library", label = "Ayanad Agent Part 2", ids = { 6638 } },
    { key = "library_agent_p3", category = "Library", label = "Ayanad Agent Part 3", ids = { 6639 } },

    { key = "arena_blood_sweat_training", category = "Arena", label = "Blood Sweat and Training", ids = { 6627 } },

    { key = "ocleera_sprouting", category = "Ocleera Rift", label = "Sprouting Ocleera Marks", ids = { 7327 } },
    { key = "ocleera_engorged", category = "Ocleera Rift", label = "Engorged Ocleera Marks", ids = { 7328 } },
    { key = "ocleera_monstrous", category = "Ocleera Rift", label = "Monstrous Ocleera Marks", ids = { 7329 } },
    { key = "ocleera_hateful", category = "Ocleera Rift", label = "Kill the Hateful Ocleera", ids = { 7330 } },

    { key = "comet_stage_1", category = "Comet Rift", label = "Rift Stage 1", ids = { 9000134 } },
    { key = "comet_stage_2", category = "Comet Rift", label = "Rift Stage 2", ids = { 9000135 } },
    { key = "comet_stage_3", category = "Comet Rift", label = "Rift Stage 3", ids = { 9000136 } },
    { key = "comet_boss", category = "Comet Rift", label = "Boss Kill", ids = { 9000143 } },

    { key = "activity_ds_pvp", category = "Activity Tokens", label = "DS PvP", ids = { 9000007, 9000008, 9000009 } },
    { key = "activity_fishing", category = "Activity Tokens", label = "Fishing", ids = { 9000011 } },
    { key = "activity_anthalon", category = "Activity Tokens", label = "Anthalon", ids = { 9000012, 9000139 } },
    { key = "activity_library_1", category = "Activity Tokens", label = "Library 1", ids = { 9000171 } },
    { key = "activity_library_2", category = "Activity Tokens", label = "Library 2", ids = { 9000172 } },
}

local WORLD_BOSS_IDS = {
    7619, 7620, 7621, 7622,
    7623, 7624, 7625, 7626,
    7627, 7628, 7629, 7630,
    7631, 7632, 7633, 7634,
    7635, 7636, 7637, 7638,
    7639, 7640, 7641, 7642,
    7643, 7644, 7645, 7646,
    7647, 7650, 7651, 7652,
    7653, 7654, 7655, 5033,
    5879, 5887, 5883, 5884
}

for _, id in ipairs(WORLD_BOSS_IDS) do
    QuestWatchData.GROUPS[#QuestWatchData.GROUPS + 1] = {
        key = "world_boss_" .. tostring(id),
        category = "World Bosses",
        label = "Quest " .. tostring(id),
        ids = { id }
    }
end

function QuestWatchData.GetGroups()
    return QuestWatchData.GROUPS
end

function QuestWatchData.BuildDefaultTracked()
    local tracked = {}
    for _, group in ipairs(QuestWatchData.GROUPS) do
        tracked[group.key] = true
    end
    return tracked
end

function QuestWatchData.CopyTracked(source)
    local tracked = {}
    if type(source) == "table" then
        for _, group in ipairs(QuestWatchData.GROUPS) do
            if source[group.key] ~= nil then
                tracked[group.key] = source[group.key] and true or false
            end
        end
    end
    for _, group in ipairs(QuestWatchData.GROUPS) do
        if tracked[group.key] == nil then
            tracked[group.key] = true
        end
    end
    return tracked
end

function QuestWatchData.EnsureTrackedDefaults(cfg)
    if type(cfg) ~= "table" then
        return false
    end
    if type(cfg.tracked) ~= "table" then
        cfg.tracked = QuestWatchData.BuildDefaultTracked()
        return true
    end

    local changed = false
    for _, group in ipairs(QuestWatchData.GROUPS) do
        if cfg.tracked[group.key] == nil then
            cfg.tracked[group.key] = true
            changed = true
        end
    end
    return changed
end

function QuestWatchData.NormalizeCharacterKey(name)
    local key = tostring(name or "")
    key = string.match(key, "^%s*(.-)%s*$") or key
    if key == "" then
        key = "player"
    end
    key = string.lower(key)
    key = string.gsub(key, "%s+", "_")
    key = string.gsub(key, "[^%w_%-]", "")
    if key == "" then
        key = "player"
    end
    return key
end

function QuestWatchData.EnsureCharacterProfile(cfg, characterName)
    if type(cfg) ~= "table" then
        return nil, nil
    end
    if type(cfg.characters) ~= "table" then
        cfg.characters = {}
    end

    local key = QuestWatchData.NormalizeCharacterKey(characterName)
    if type(cfg.characters[key]) ~= "table" then
        cfg.characters[key] = {
            tracked = QuestWatchData.CopyTracked(cfg.tracked),
            collapsed = cfg.collapsed and true or false,
            completed_view = cfg.completed_view and true or false
        }
    end

    local profile = cfg.characters[key]
    if type(profile.tracked) ~= "table" then
        profile.tracked = QuestWatchData.CopyTracked(cfg.tracked)
    else
        QuestWatchData.EnsureTrackedDefaults(profile)
    end
    if profile.collapsed == nil then
        profile.collapsed = cfg.collapsed and true or false
    end
    if profile.completed_view == nil then
        profile.completed_view = cfg.completed_view and true or false
    end
    return profile, key
end

return QuestWatchData
