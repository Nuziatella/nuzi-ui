local SettingsSchema = {}

local function extend(base, extra)
    local out = {}
    if type(base) == "table" then
        for key, value in pairs(base) do
            out[key] = value
        end
    end
    if type(extra) == "table" then
        for key, value in pairs(extra) do
            out[key] = value
        end
    end
    return out
end

local function checkbox(control, widgetId, label, extra)
    return extend({
        kind = "checkbox",
        control = control,
        widget_id = widgetId,
        label = label
    }, extra)
end

local function slider(control, widgetId, label, minVal, maxVal, step, extra)
    return extend({
        kind = "slider",
        control = control,
        value_control = tostring(control) .. "_val",
        widget_id = widgetId,
        label = label,
        min = minVal,
        max = maxVal,
        step = step
    }, extra)
end

local function combo(control, widgetId, label, items, extra)
    return extend({
        kind = "combo",
        control = control,
        widget_id = widgetId,
        label = label,
        items = items
    }, extra)
end

local function hint(control, widgetId, text, extra)
    return extend({
        kind = "hint",
        control = control,
        widget_id = widgetId,
        text = text
    }, extra)
end

local function label(control, widgetId, text, extra)
    return extend({
        kind = "label",
        control = control,
        widget_id = widgetId,
        text = text
    }, extra)
end

local function custom(renderer, extra)
    return extend({
        kind = "custom",
        renderer = renderer
    }, extra)
end

local STYLE_TARGET_ITEMS = {
    "All frames",
    "Player",
    "Target",
    "Watchtarget",
    "Target of Target",
    "Party"
}

local CASTBAR_TEXTURE_ITEMS = {
    "Auto",
    "Casting",
    "Charge"
}

local CASTBAR_FILL_STYLE_ITEMS = {
    "Texture",
    "Solid"
}

local DEBUFF_ANCHOR_ITEMS = {
    "Top",
    "Left",
    "Right"
}

SettingsSchema.PAGES = {
    general = {
        sections = {
            {
                id = "general_core",
                title = "Core",
                hint = "Shared addon toggles that affect all custom unit frame overlays.",
                fields = {
                    checkbox("enabled", "polarUiEnabled", "Enable Nuzi UI overlays"),
                    checkbox("drag_requires_shift", "polarUiDragRequiresShift", "Require Shift to move frames"),
                    checkbox("large_hpmp", "polarUiLargeHpMp", "Large HP/MP text"),
                    checkbox("alignment_grid_enabled", "polarUiAlignmentGridEnabled", "Show alignment grid (30px)")
                }
            },
            {
                id = "general_launcher",
                title = "Launcher Button",
                hint = "Control the floating settings button used to open the addon window in game.",
                fields = {
                    slider("launcher_size", "polarUiLauncherSize", "Launcher size", 36, 96, 1)
                }
            }
        }
    },
    repair = {
        sections = {
            {
                id = "repair_diagnostics",
                title = "Diagnostics",
                hint = "Check the client UI scale, screen size, and saved layout positions used by Nuzi UI.",
                fields = {
                    custom("ui_repair_diagnostics", { estimate_height = 118 })
                }
            },
            {
                id = "repair_actions",
                title = "Repair Actions",
                hint = "Use these when frames are off screen, drifting, or look wrong after changing UI scale.",
                fields = {
                    custom("ui_repair_actions", { estimate_height = 254 })
                }
            }
        }
    },
    npc = {
        sections = {
            {
                id = "npc_unit_art",
                title = "Unit Frame Art",
                hint = "Hide stock heir and level decorations that can overlap the custom player frame text.",
                fields = {
                    checkbox("hide_ancestral_icon_level", "polarUiHideAncestralLevel", "Hide ancestral icon and level")
                }
            },
            {
                id = "npc_target_frame",
                title = "Target Frame",
                hint = "Control stock boss decorations and other native target-frame elements.",
                fields = {
                    checkbox("hide_boss_frame_background", "polarUiHideBossBackground", "Hide boss frame background"),
                    checkbox("hide_target_grade_star", "polarUiHideTargetGradeStar", "Hide target grade stars"),
                    checkbox("show_distance", "polarUiShowDistance", "Show target distance")
                }
            },
            {
                id = "npc_grade_star",
                title = "Grade Star Placement",
                hint = "When grade stars stay visible, you can offset them to fit your frame layout.",
                fields = {
                    hint(
                        "npc_grade_star_hint",
                        "polarUiNpcGradeStarHint",
                        "Offsets apply when grade stars are visible. Zero keeps the stock placement.",
                        { depends_on = { control = "hide_target_grade_star", checked = false }, width = 540 }
                    ),
                    slider(
                        "target_grade_star_offset_x",
                        "polarUiTargetGradeStarOffsetX",
                        "Grade star offset X",
                        -200,
                        200,
                        1,
                        { depends_on = { control = "hide_target_grade_star", checked = false } }
                    ),
                    slider(
                        "target_grade_star_offset_y",
                        "polarUiTargetGradeStarOffsetY",
                        "Grade star offset Y",
                        -200,
                        200,
                        1,
                        { depends_on = { control = "hide_target_grade_star", checked = false } }
                    )
                }
            }
        }
    },
    text = {
        sections = {
            {
                id = "text_style_target",
                title = "Style Target",
                hint = "Choose whether text settings edit the shared defaults or a per-frame override.",
                fields = {
                    combo("style_target_text", "polarUiTextStyleTarget", "Edit style for", STYLE_TARGET_ITEMS),
                    hint(
                        "style_target_text_hint",
                        "polarUiTextStyleTargetHint",
                        "Editing shared defaults for all overlay and party frames."
                    )
                }
            },
            {
                id = "text_font_sizes",
                title = "Font Sizes",
                hint = "Tune the size of names, values, and the target overlay details independently.",
                fields = {
                    slider("name_font_size", "polarUiNameFontSize", "Name font size", 8, 30, 1),
                    slider("hp_font_size", "polarUiHpFontSize", "HP font size", 8, 40, 1),
                    slider("mp_font_size", "polarUiMpFontSize", "MP font size", 8, 40, 1),
                    slider("overlay_font_size", "polarUiOverlayFontSize", "Target overlay font size", 8, 30, 1),
                    slider("gs_font_size", "polarUiGsFontSize", "Gearscore font size", 8, 30, 1),
                    slider("class_font_size", "polarUiClassFontSize", "Class font size", 8, 30, 1),
                    slider("target_guild_font_size", "polarUiTargetGuildFontSize", "Target guild font size", 8, 30, 1)
                }
            },
            {
                id = "text_overlay_fields",
                title = "Target Overlay Fields",
                hint = "Choose which extra target details remain visible on the overlay.",
                fields = {
                    checkbox("target_guild_visible", "polarUiTargetGuildVisible", "Show guild/family text"),
                    checkbox("target_class_visible", "polarUiTargetClassVisible", "Show class text"),
                    checkbox("target_pdef_visible", "polarUiTargetPdefVisible", "Show PDEF text"),
                    checkbox("target_mdef_visible", "polarUiTargetMdefVisible", "Show MDEF text"),
                    checkbox("target_gearscore_visible", "polarUiTargetGearscoreVisible", "Show gearscore text")
                }
            },
            {
                id = "text_overlay_colors",
                title = "Target Overlay Colors",
                hint = "Adjust the per-field colors used for guild, class, defense, and gearscore text.",
                fields = {
                    label(nil, "polarUiTargetGuildColorHeader", "Guild Color", { font_size = 15 }),
                    slider("target_guild_r", "polarUiTargetGuildR", "Guild R", 0, 255, 1),
                    slider("target_guild_g", "polarUiTargetGuildG", "Guild G", 0, 255, 1),
                    slider("target_guild_b", "polarUiTargetGuildB", "Guild B", 0, 255, 1),
                    label(nil, "polarUiTargetClassColorHeader", "Class Color", { font_size = 15, advance = 28 }),
                    slider("target_class_r", "polarUiTargetClassR", "Class R", 0, 255, 1),
                    slider("target_class_g", "polarUiTargetClassG", "Class G", 0, 255, 1),
                    slider("target_class_b", "polarUiTargetClassB", "Class B", 0, 255, 1),
                    label(nil, "polarUiTargetPdefColorHeader", "PDEF Color", { font_size = 15, advance = 28 }),
                    slider("target_pdef_r", "polarUiTargetPdefR", "PDEF R", 0, 255, 1),
                    slider("target_pdef_g", "polarUiTargetPdefG", "PDEF G", 0, 255, 1),
                    slider("target_pdef_b", "polarUiTargetPdefB", "PDEF B", 0, 255, 1),
                    label(nil, "polarUiTargetMdefColorHeader", "MDEF Color", { font_size = 15, advance = 28 }),
                    slider("target_mdef_r", "polarUiTargetMdefR", "MDEF R", 0, 255, 1),
                    slider("target_mdef_g", "polarUiTargetMdefG", "MDEF G", 0, 255, 1),
                    slider("target_mdef_b", "polarUiTargetMdefB", "MDEF B", 0, 255, 1),
                    label(nil, "polarUiTargetGsColorHeader", "Gearscore Color", { font_size = 15, advance = 28 }),
                    slider("target_gearscore_r", "polarUiTargetGsR", "Gearscore R", 0, 255, 1),
                    slider("target_gearscore_g", "polarUiTargetGsG", "Gearscore G", 0, 255, 1),
                    slider("target_gearscore_b", "polarUiTargetGsB", "Gearscore B", 0, 255, 1)
                }
            },
            {
                id = "text_shadows",
                title = "Shadows",
                hint = "Improve readability against busy backgrounds by applying text shadows where needed.",
                fields = {
                    checkbox("name_shadow", "polarUiNameShadow", "Name text shadow"),
                    checkbox("value_shadow", "polarUiValueShadow", "HP/MP value shadow"),
                    checkbox("overlay_shadow", "polarUiOverlayShadow", "Target overlay shadow")
                }
            },
            {
                id = "text_value_offsets",
                title = "HP/MP Value Offsets",
                hint = "Fine tune where the HP, MP, and target guild/family text sit on the frame.",
                fields = {
                    slider("hp_value_offset_x", "polarUiHpValueOffsetX", "HP value offset X", -200, 200, 1),
                    slider("hp_value_offset_y", "polarUiHpValueOffsetY", "HP value offset Y", -120, 120, 1),
                    slider("mp_value_offset_x", "polarUiMpValueOffsetX", "MP value offset X", -200, 200, 1),
                    slider("mp_value_offset_y", "polarUiMpValueOffsetY", "MP value offset Y", -120, 120, 1),
                    slider("target_guild_offset_x", "polarUiTargetGuildOffsetX", "Target guild offset X", -200, 200, 1),
                    slider("target_guild_offset_y", "polarUiTargetGuildOffsetY", "Target guild offset Y", -200, 200, 1)
                }
            },
            {
                id = "text_layout",
                title = "Text Layout",
                hint = "Control name and level visibility, sizing, and placement.",
                fields = {
                    checkbox("name_visible", "polarUiNameVisible", "Show name text"),
                    slider("name_offset_x", "polarUiNameOffsetX", "Name offset X", -200, 200, 1),
                    slider("name_offset_y", "polarUiNameOffsetY", "Name offset Y", -120, 120, 1),
                    checkbox("level_visible", "polarUiLevelVisible", "Show level text"),
                    slider("level_font_size", "polarUiLevelFontSize", "Level font size", 8, 24, 1),
                    slider("level_offset_x", "polarUiLevelOffsetX", "Level offset X", -200, 200, 1),
                    slider("level_offset_y", "polarUiLevelOffsetY", "Level offset Y", -120, 120, 1)
                }
            }
        }
    },
    bars = {
        sections = {
            {
                id = "bars_style_target",
                title = "Style Target",
                hint = "Choose whether bar settings edit the shared defaults or a per-frame override.",
                fields = {
                    combo("style_target_bars", "polarUiBarsStyleTarget", "Edit style for", STYLE_TARGET_ITEMS),
                    hint(
                        "style_target_bars_hint",
                        "polarUiBarsStyleTargetHint",
                        "Editing shared defaults for all overlay and party frames."
                    )
                }
            },
            {
                id = "bars_frame_styling",
                title = "Frame Styling",
                hint = "Adjust opacity and the overall footprint of the frame before tuning the bars themselves.",
                fields = {
                    slider("frame_alpha", "polarUiFrameAlpha", "Frame alpha (0-100)", 0, 100, 1),
                    slider("overlay_alpha", "polarUiOverlayAlpha", "Overlay alpha (0-100)", 0, 100, 1),
                    slider("frame_width", "polarUiFrameWidth", "Frame width", 200, 600, 1),
                    slider("frame_height", "polarUiFrameHeight", "Frame height (global)", 40, 120, 1),
                    slider("frame_scale", "polarUiFrameScale", "Frame scale (50-150)", 50, 150, 1)
                }
            },
            {
                id = "bars_layout",
                title = "Bar Layout",
                hint = "Control shared and per-bar heights plus the spacing between the HP and MP bars.",
                fields = {
                    slider("bar_height", "polarUiBarHeight", "Shared bar height", 10, 40, 1),
                    slider("hp_bar_height", "polarUiHpBarHeight", "HP bar height", 6, 40, 1),
                    slider("mp_bar_height", "polarUiMpBarHeight", "MP bar height", 6, 40, 1),
                    slider("bar_gap", "polarUiBarGap", "Bar gap", 0, 20, 1)
                }
            },
            {
                id = "bars_colors",
                title = "Bar Colors",
                hint = "Override the stock HP and MP colors when you want a fully custom palette.",
                fields = {
                    checkbox("bar_colors_enabled", "polarUiBarColorsEnabled", "Override HP/MP bar colors"),
                    label(nil, "polarUiHpColorLabel", "HP Fill", { font_size = 15, depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("hp_r", "polarUiHpR", "HP R", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("hp_g", "polarUiHpG", "HP G", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("hp_b", "polarUiHpB", "HP B", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("hp_a", "polarUiHpA", "HP Fill alpha", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    label(nil, "polarUiHpAfterColorLabel", "HP Afterimage", { font_size = 15, advance = 28, depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("hp_after_r", "polarUiHpAfterR", "HP After R", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("hp_after_g", "polarUiHpAfterG", "HP After G", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("hp_after_b", "polarUiHpAfterB", "HP After B", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("hp_after_a", "polarUiHpAfterA", "HP After alpha", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    checkbox("hostile_target_hp_enabled", "polarUiHostileTargetHpEnabled", "Hostile target HP color"),
                    label(nil, "polarUiHostileTargetHpColorLabel", "Hostile Target HP", { font_size = 15, depends_on = { control = "hostile_target_hp_enabled", checked = true } }),
                    slider("hostile_target_hp_r", "polarUiHostileTargetHpR", "Hostile HP R", 0, 255, 1, { depends_on = { control = "hostile_target_hp_enabled", checked = true } }),
                    slider("hostile_target_hp_g", "polarUiHostileTargetHpG", "Hostile HP G", 0, 255, 1, { depends_on = { control = "hostile_target_hp_enabled", checked = true } }),
                    slider("hostile_target_hp_b", "polarUiHostileTargetHpB", "Hostile HP B", 0, 255, 1, { depends_on = { control = "hostile_target_hp_enabled", checked = true } }),
                    slider("hostile_target_hp_a", "polarUiHostileTargetHpA", "Hostile HP alpha", 0, 255, 1, { depends_on = { control = "hostile_target_hp_enabled", checked = true } }),
                    label(nil, "polarUiMpColorLabel", "MP Fill", { font_size = 15, advance = 28, depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("mp_r", "polarUiMpR", "MP R", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("mp_g", "polarUiMpG", "MP G", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("mp_b", "polarUiMpB", "MP B", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("mp_a", "polarUiMpA", "MP Fill alpha", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    label(nil, "polarUiMpAfterColorLabel", "MP Afterimage", { font_size = 15, advance = 28, depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("mp_after_r", "polarUiMpAfterR", "MP After R", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("mp_after_g", "polarUiMpAfterG", "MP After G", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("mp_after_b", "polarUiMpAfterB", "MP After B", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } }),
                    slider("mp_after_a", "polarUiMpAfterA", "MP After alpha", 0, 255, 1, { depends_on = { control = "bar_colors_enabled", checked = true } })
                }
            },
            {
                id = "bars_texture_mode",
                title = "HP Texture Mode",
                hint = "Pick which stock texture family the HP bar should use when custom colors are not enough.",
                fields = {
                    checkbox("hp_tex_stock", "polarUiHpTexStock", "Stock"),
                    checkbox("hp_tex_pc", "polarUiHpTexPc", "PC"),
                    checkbox("hp_tex_npc", "polarUiHpTexNpc", "NPC")
                }
            },
            {
                id = "bars_value_text",
                title = "HP/MP Value Text",
                hint = "Choose how health and mana values are formatted for display.",
                fields = {
                    checkbox("value_fmt_curmax", "polarUiValueFmtCurMax", "Format HP/MP as cur/max"),
                    checkbox("value_fmt_percent", "polarUiValueFmtPercent", "Format HP/MP as percent"),
                    checkbox("short_numbers", "polarUiShortNumbers", "Short numbers (12.3k/4.5m)")
                }
            }
        }
    },
    castbar = {
        sections = {
            {
                id = "castbar_behavior",
                title = "Player Cast Bar",
                hint = "Show a movable player cast bar that only appears while you are casting.",
                fields = {
                    checkbox("castbar_enabled", "polarUiCastBarEnabled", "Enable player cast bar"),
                    hint(
                        "castbar_move_hint",
                        "polarUiCastBarMoveHint",
                        "Drag in game to move the cast bar. If Shift movement is enabled in General, hold Shift while dragging.",
                        { width = 520, depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    hint(
                        "castbar_preview_hint",
                        "polarUiCastBarPreviewHint",
                        "A live preview is shown while this page is open.",
                        { width = 520, depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    checkbox(
                        "castbar_lock_position",
                        "polarUiCastBarLockPosition",
                        "Lock cast bar position",
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    )
                }
            },
            {
                id = "castbar_layout",
                title = "Layout",
                hint = "Tune the cast bar size, fill style, texture preset, and border thickness.",
                fields = {
                    slider(
                        "castbar_width",
                        "polarUiCastBarWidth",
                        "Bar width",
                        240,
                        620,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_scale",
                        "polarUiCastBarScale",
                        "Bar scale (80-200)",
                        80,
                        200,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    combo(
                        "castbar_texture_mode",
                        "polarUiCastBarTextureMode",
                        "Texture mode",
                        CASTBAR_TEXTURE_ITEMS,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    combo(
                        "castbar_fill_style",
                        "polarUiCastBarFillStyle",
                        "Fill style",
                        CASTBAR_FILL_STYLE_ITEMS,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_border_thickness",
                        "polarUiCastBarBorderThickness",
                        "Border thickness",
                        0,
                        12,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    )
                }
            },
            {
                id = "castbar_text",
                title = "Text",
                hint = "Adjust the spell text color, size, and placement under the bar.",
                fields = {
                    slider(
                        "castbar_text_font_size",
                        "polarUiCastBarTextFontSize",
                        "Text size",
                        10,
                        24,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_text_offset_x",
                        "polarUiCastBarTextOffsetX",
                        "Text offset X",
                        -120,
                        120,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_text_offset_y",
                        "polarUiCastBarTextOffsetY",
                        "Text offset Y",
                        -40,
                        60,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    label(
                        "castbar_text_color_label",
                        "polarUiCastBarTextColorLabel",
                        "Text color",
                        { depends_on = { control = "castbar_enabled", checked = true }, font_size = 15 }
                    ),
                    slider(
                        "castbar_text_r",
                        "polarUiCastBarTextR",
                        "Text R",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_text_g",
                        "polarUiCastBarTextG",
                        "Text G",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_text_b",
                        "polarUiCastBarTextB",
                        "Text B",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_text_a",
                        "polarUiCastBarTextA",
                        "Text alpha",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    )
                }
            },
            {
                id = "castbar_colors",
                title = "Colors",
                hint = "Customize the bar fill, background, and accent strip colors.",
                fields = {
                    label(
                        "castbar_fill_label",
                        "polarUiCastBarFillLabel",
                        "Fill color",
                        { depends_on = { control = "castbar_enabled", checked = true }, font_size = 15 }
                    ),
                    slider(
                        "castbar_fill_r",
                        "polarUiCastBarFillR",
                        "Fill R",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_fill_g",
                        "polarUiCastBarFillG",
                        "Fill G",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_fill_b",
                        "polarUiCastBarFillB",
                        "Fill B",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_fill_a",
                        "polarUiCastBarFillA",
                        "Fill alpha",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    label(
                        "castbar_bg_label",
                        "polarUiCastBarBgLabel",
                        "Background color",
                        { depends_on = { control = "castbar_enabled", checked = true }, font_size = 15 }
                    ),
                    slider(
                        "castbar_bg_r",
                        "polarUiCastBarBgR",
                        "Background R",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_bg_g",
                        "polarUiCastBarBgG",
                        "Background G",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_bg_b",
                        "polarUiCastBarBgB",
                        "Background B",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_bg_a",
                        "polarUiCastBarBgA",
                        "Background alpha",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    label(
                        "castbar_accent_label",
                        "polarUiCastBarAccentLabel",
                        "Accent color",
                        { depends_on = { control = "castbar_enabled", checked = true }, font_size = 15 }
                    ),
                    slider(
                        "castbar_accent_r",
                        "polarUiCastBarAccentR",
                        "Accent R",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_accent_g",
                        "polarUiCastBarAccentG",
                        "Accent G",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_accent_b",
                        "polarUiCastBarAccentB",
                        "Accent B",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    ),
                    slider(
                        "castbar_accent_a",
                        "polarUiCastBarAccentA",
                        "Accent alpha",
                        0,
                        255,
                        1,
                        { depends_on = { control = "castbar_enabled", checked = true } }
                    )
                }
            }
        }
    },
    travel = {
        sections = {
            {
                id = "travel_behavior",
                title = "Travel Speed",
                hint = "Show a compact ArcheAge-style speed meter for vehicles and general movement.",
                fields = {
                    checkbox("travel_speed_enabled", "polarUiTravelSpeedEnabled", "Enable travel speed meter"),
                    hint(
                        "travel_speed_move_hint",
                        "polarUiTravelSpeedMoveHint",
                        "Drag in game to move the speed meter. If Shift movement is enabled in General, hold Shift while dragging.",
                        { width = 520, depends_on = { control = "travel_speed_enabled", checked = true } }
                    ),
                    checkbox(
                        "travel_speed_lock_position",
                        "polarUiTravelSpeedLockPosition",
                        "Lock speed meter position",
                        { depends_on = { control = "travel_speed_enabled", checked = true } }
                    ),
                    checkbox(
                        "travel_speed_only_vehicle_or_mount",
                        "polarUiTravelSpeedOnlyVehicleOrMount",
                        "Only show on vehicle or mount",
                        { depends_on = { control = "travel_speed_enabled", checked = true } }
                    ),
                    checkbox(
                        "travel_speed_show_on_mount",
                        "polarUiTravelSpeedShowOnMount",
                        "Show for mounts",
                        { depends_on = { control = "travel_speed_enabled", checked = true } }
                    ),
                    checkbox(
                        "travel_speed_show_on_vehicle",
                        "polarUiTravelSpeedShowOnVehicle",
                        "Show for vehicles",
                        { depends_on = { control = "travel_speed_enabled", checked = true } }
                    ),
                    checkbox(
                        "travel_speed_show_bar",
                        "polarUiTravelSpeedShowBar",
                        "Show speed bar",
                        { depends_on = { control = "travel_speed_enabled", checked = true } }
                    ),
                    checkbox(
                        "travel_speed_show_state_text",
                        "polarUiTravelSpeedShowStateText",
                        "Show state text",
                        { depends_on = { control = "travel_speed_enabled", checked = true } }
                    )
                }
            },
            {
                id = "travel_layout",
                title = "Layout",
                hint = "Tune the compact travel speed panel without changing the rest of the UI.",
                fields = {
                    slider(
                        "travel_speed_width",
                        "polarUiTravelSpeedWidth",
                        "Panel width",
                        160,
                        360,
                        1,
                        { depends_on = { control = "travel_speed_enabled", checked = true } }
                    ),
                    slider(
                        "travel_speed_scale",
                        "polarUiTravelSpeedScale",
                        "Panel scale (75-160)",
                        75,
                        160,
                        1,
                        { depends_on = { control = "travel_speed_enabled", checked = true } }
                    ),
                    slider(
                        "travel_speed_font_size",
                        "polarUiTravelSpeedFontSize",
                        "Speed text size",
                        14,
                        30,
                        1,
                        { depends_on = { control = "travel_speed_enabled", checked = true } }
                    )
                }
            }
        }
    },
    loadouts = {
        sections = {
            {
                id = "loadouts_behavior",
                title = "Gear Loadouts",
                hint = "Show a per-character loadout bar and editor for saving gear sets.",
                fields = {
                    checkbox("gear_loadouts_enabled", "polarUiGearLoadoutsEnabled", "Enable gear loadouts"),
                    hint(
                        "gear_loadouts_move_hint",
                        "polarUiGearLoadoutsMoveHint",
                        "Drag in game to move the bar or editor. If Shift movement is enabled in General, hold Shift while dragging.",
                        { width = 520, depends_on = { control = "gear_loadouts_enabled", checked = true } }
                    ),
                    custom("gear_loadouts_editor_button", { estimate_height = 34 }),
                    checkbox(
                        "gear_loadouts_lock_bar",
                        "polarUiGearLoadoutsLockBar",
                        "Lock loadout bar position",
                        { depends_on = { control = "gear_loadouts_enabled", checked = true } }
                    ),
                    checkbox(
                        "gear_loadouts_lock_editor",
                        "polarUiGearLoadoutsLockEditor",
                        "Lock editor position",
                        { depends_on = { control = "gear_loadouts_enabled", checked = true } }
                    ),
                    checkbox(
                        "gear_loadouts_show_icons",
                        "polarUiGearLoadoutsShowIcons",
                        "Show loadout icons on bar",
                        { depends_on = { control = "gear_loadouts_enabled", checked = true } }
                    )
                }
            },
            {
                id = "loadouts_layout",
                title = "Bar Layout",
                hint = "Tune the clickable loadout bar without changing saved loadouts.",
                fields = {
                    slider(
                        "gear_loadouts_button_size",
                        "polarUiGearLoadoutsButtonSize",
                        "Icon size",
                        28,
                        58,
                        1,
                        { depends_on = { control = "gear_loadouts_enabled", checked = true } }
                    ),
                    slider(
                        "gear_loadouts_button_width",
                        "polarUiGearLoadoutsButtonWidth",
                        "Name button width",
                        80,
                        220,
                        1,
                        { depends_on = { control = "gear_loadouts_enabled", checked = true } }
                    )
                }
            }
        }
    },
    auras = {
        sections = {
            {
                id = "auras_layout",
                title = "Aura Layout",
                hint = "Override icon size, spacing, and growth rules for the buff and debuff windows.",
                fields = {
                    checkbox("aura_enabled", "polarUiAuraEnabled", "Override aura icon layout"),
                    slider("aura_icon_size", "polarUiAuraIconSize", "Icon size", 12, 48, 1, { depends_on = { control = "aura_enabled", checked = true } }),
                    slider("aura_x_gap", "polarUiAuraXGap", "Icon X gap", 0, 10, 1, { depends_on = { control = "aura_enabled", checked = true } }),
                    slider("aura_y_gap", "polarUiAuraYGap", "Icon Y gap", 0, 10, 1, { depends_on = { control = "aura_enabled", checked = true } }),
                    slider("aura_per_row", "polarUiAuraPerRow", "Icons per row", 1, 30, 1, { depends_on = { control = "aura_enabled", checked = true } }),
                    checkbox("aura_sort_vertical", "polarUiAuraSortVertical", "Sort vertical", { depends_on = { control = "aura_enabled", checked = true } }),
                    checkbox("aura_reverse_growth", "polarUiAuraReverseGrowth", "Reverse growth", { depends_on = { control = "aura_enabled", checked = true } })
                }
            },
            {
                id = "auras_buff_placement",
                title = "Buff and Debuff Placement",
                hint = "Use settings.txt backed offsets to move the stock buff strips for player and target.",
                fields = {
                    checkbox("move_buffs", "polarUiMoveBuffs", "Move buff/debuff strips (uses settings.txt offsets)"),
                    label(nil, "polarUiBuffPlacementPlayer", "Player", { font_size = 15, depends_on = { control = "move_buffs", checked = true } }),
                    slider("p_buff_x", "polarUiPBX", "Buff X", -200, 200, 1, { depends_on = { control = "move_buffs", checked = true } }),
                    slider("p_buff_y", "polarUiPBY", "Buff Y", -200, 200, 1, { depends_on = { control = "move_buffs", checked = true } }),
                    slider("p_debuff_x", "polarUiPDBX", "Debuff X", -200, 200, 1, { depends_on = { control = "move_buffs", checked = true } }),
                    slider("p_debuff_y", "polarUiPDBY", "Debuff Y", -200, 200, 1, { depends_on = { control = "move_buffs", checked = true } }),
                    label(nil, "polarUiBuffPlacementTarget", "Target", { font_size = 15, advance = 28, depends_on = { control = "move_buffs", checked = true } }),
                    slider("t_buff_x", "polarUiTBX", "Buff X", -200, 200, 1, { depends_on = { control = "move_buffs", checked = true } }),
                    slider("t_buff_y", "polarUiTBY", "Buff Y", -200, 200, 1, { depends_on = { control = "move_buffs", checked = true } }),
                    slider("t_debuff_x", "polarUiTDBX", "Debuff X", -200, 200, 1, { depends_on = { control = "move_buffs", checked = true } }),
                    slider("t_debuff_y", "polarUiTDBY", "Debuff Y", -200, 200, 1, { depends_on = { control = "move_buffs", checked = true } })
                }
            }
        }
    },
    plates = {
        sections = {
            {
                id = "plates_behavior",
                title = "Behavior",
                hint = "Control which nameplates get custom overhead bars and how the runtime behaves.",
                fields = {
                    checkbox("plates_enabled", "polarUiPlatesEnabled", "Enable overhead plates"),
                    checkbox("plates_guild_only", "polarUiPlatesGuildOnly", "Guild-only overlay (keep stock nameplates)"),
                    checkbox("plates_show_target", "polarUiPlatesShowTarget", "Show target (always)"),
                    checkbox("plates_show_player", "polarUiPlatesShowPlayer", "Show player (always)"),
                    checkbox("plates_show_raid_party", "polarUiPlatesShowRaid", "Show raid/party (team1..team50)"),
                    checkbox("plates_show_watchtarget", "polarUiPlatesShowWatch", "Show watchtarget"),
                    checkbox("plates_show_mount", "polarUiPlatesShowMount", "Show mount/pet (playerpet1)"),
                    checkbox("plates_show_guild", "polarUiPlatesShowGuild", "Show guild/family"),
                    label(
                        "plates_runtime_note",
                        "polarUiPlatesRuntimeNote",
                        "Current client supports native targeting, so the old passthrough click modifiers are no longer needed.",
                        { font_size = 13, width = 470, advance = 38 }
                    ),
                    hint("plates_runtime_status", "polarUiPlatesRuntimeStatus", "", { width = 470, advance = 30 })
                }
            },
            {
                id = "plates_layout",
                title = "Layout",
                hint = "Set transparency, dimensions, and anchoring for the overhead plate bars.",
                fields = {
                    slider("plates_alpha", "polarUiPlatesAlpha", "Transparency (0-100)", 0, 100, 1),
                    slider("plates_width", "polarUiPlatesWidth", "Width", 50, 250, 1),
                    slider("plates_hp_h", "polarUiPlatesHpHeight", "HP height", 5, 60, 1),
                    slider("plates_mp_h", "polarUiPlatesMpHeight", "MP height (0 hides)", 0, 40, 1),
                    slider("plates_x_offset", "polarUiPlatesXOffset", "X offset", -200, 200, 1),
                    slider("plates_max_dist", "polarUiPlatesMaxDistance", "Max distance", 1, 300, 1),
                    slider("plates_y_offset", "polarUiPlatesYOffset", "Y offset", -100, 100, 1),
                    checkbox("plates_anchor_tag", "polarUiPlatesAnchorToTag", "Anchor to stock name tag"),
                    checkbox("plates_bg_enabled", "polarUiPlatesBgEnabled", "Show background"),
                    slider("plates_bg_alpha", "polarUiPlatesBgAlpha", "Background alpha (0-100)", 0, 100, 1, { depends_on = { control = "plates_bg_enabled", checked = true } })
                }
            },
            {
                id = "plates_text",
                title = "Text",
                hint = "Adjust the font size used for names and guild/family text on overhead plates.",
                fields = {
                    slider("plates_name_fs", "polarUiPlatesNameFontSize", "Name font size", 6, 32, 1),
                    slider("plates_guild_fs", "polarUiPlatesGuildFontSize", "Guild font size", 6, 32, 1)
                }
            },
            {
                id = "plates_debuffs",
                title = "Debuffs",
                hint = "Show Gharka-style priority debuffs near the stock overhead nameplate.",
                fields = {
                    checkbox("plates_debuffs_enabled", "polarUiPlatesDebuffsEnabled", "Enable stock-nameplate debuffs"),
                    checkbox(
                        "plates_debuffs_track_raid",
                        "polarUiPlatesDebuffsTrackRaid",
                        "Track raid/party units",
                        { depends_on = { control = "plates_debuffs_enabled", checked = true } }
                    ),
                    checkbox(
                        "plates_debuffs_show_timer",
                        "polarUiPlatesDebuffsShowTimer",
                        "Show timers",
                        { depends_on = { control = "plates_debuffs_enabled", checked = true } }
                    ),
                    checkbox(
                        "plates_debuffs_show_secondary",
                        "polarUiPlatesDebuffsShowSecondary",
                        "Show secondary icons",
                        { depends_on = { control = "plates_debuffs_enabled", checked = true } }
                    ),
                    combo(
                        "plates_debuffs_anchor",
                        "polarUiPlatesDebuffsAnchor",
                        "Anchor",
                        DEBUFF_ANCHOR_ITEMS,
                        { depends_on = { control = "plates_debuffs_enabled", checked = true }, width = 160 }
                    ),
                    slider(
                        "plates_debuffs_max_icons",
                        "polarUiPlatesDebuffsMaxIcons",
                        "Max icons",
                        1,
                        4,
                        1,
                        { depends_on = { control = "plates_debuffs_enabled", checked = true } }
                    ),
                    slider(
                        "plates_debuffs_icon_size",
                        "polarUiPlatesDebuffsIconSize",
                        "Main size",
                        16,
                        48,
                        1,
                        { depends_on = { control = "plates_debuffs_enabled", checked = true } }
                    ),
                    slider(
                        "plates_debuffs_secondary_size",
                        "polarUiPlatesDebuffsSecondarySize",
                        "Small size",
                        10,
                        32,
                        1,
                        { depends_on = { control = "plates_debuffs_enabled", checked = true } }
                    ),
                    slider(
                        "plates_debuffs_timer_size",
                        "polarUiPlatesDebuffsTimerSize",
                        "Timer size",
                        8,
                        24,
                        1,
                        { depends_on = { control = "plates_debuffs_enabled", checked = true } }
                    ),
                    slider(
                        "plates_debuffs_gap",
                        "polarUiPlatesDebuffsGap",
                        "Gap",
                        0,
                        12,
                        1,
                        { depends_on = { control = "plates_debuffs_enabled", checked = true } }
                    ),
                    slider(
                        "plates_debuffs_offset_x",
                        "polarUiPlatesDebuffsOffsetX",
                        "Offset X",
                        -120,
                        120,
                        1,
                        { depends_on = { control = "plates_debuffs_enabled", checked = true } }
                    ),
                    slider(
                        "plates_debuffs_offset_y",
                        "polarUiPlatesDebuffsOffsetY",
                        "Offset Y",
                        -120,
                        120,
                        1,
                        { depends_on = { control = "plates_debuffs_enabled", checked = true } }
                    ),
                    label(
                        "plates_debuffs_categories_label",
                        "polarUiPlatesDebuffsCategoriesLabel",
                        "Categories",
                        { font_size = 15, advance = 28, depends_on = { control = "plates_debuffs_enabled", checked = true } }
                    ),
                    checkbox("plates_debuffs_show_hard", "polarUiPlatesDebuffsShowHard", "Hard CC", { depends_on = { control = "plates_debuffs_enabled", checked = true } }),
                    checkbox("plates_debuffs_show_silence", "polarUiPlatesDebuffsShowSilence", "Silence / disarm", { depends_on = { control = "plates_debuffs_enabled", checked = true } }),
                    checkbox("plates_debuffs_show_root", "polarUiPlatesDebuffsShowRoot", "Root / snare", { depends_on = { control = "plates_debuffs_enabled", checked = true } }),
                    checkbox("plates_debuffs_show_slow", "polarUiPlatesDebuffsShowSlow", "Slows", { depends_on = { control = "plates_debuffs_enabled", checked = true } }),
                    checkbox("plates_debuffs_show_dot", "polarUiPlatesDebuffsShowDot", "DoTs", { depends_on = { control = "plates_debuffs_enabled", checked = true } }),
                    checkbox("plates_debuffs_show_misc", "polarUiPlatesDebuffsShowMisc", "Misc CC", { depends_on = { control = "plates_debuffs_enabled", checked = true } })
                }
            },
            {
                id = "plates_guild_colors",
                title = "Guild Colors",
                hint = "Define per-guild color overrides and manage them directly from the settings window.",
                fields = {
                    custom("plates_guild_colors", { estimate_height = 276 })
                }
            }
        }
    }
}

return SettingsSchema
