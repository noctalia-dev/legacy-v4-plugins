-- Steam Overlay — custom Hyprland Lua layout
-- =========================================================================
-- Requires Hyprland >= 0.55 with a Lua config (hyprland.lua).
--
-- This is OPTIONAL. It only matters if you enable "Use custom Hyprland
-- layout" in the plugin settings. When active, the plugin just moves the
-- Steam windows into the `special:steam` workspace and this layout tiles
-- them into Friends | Main | Chat columns (auto-reflowing, no floating,
-- no pixel math, no polling).
--
-- SETUP
--   1. Copy this file next to your Lua config:
--        cp steam-layout.lua ~/.config/hypr/steam-layout.lua
--   2. In ~/.config/hypr/hyprland.lua add:
--        require("steam-layout")
--        hl.workspace_rule({ workspace = "special:steam", layout = "lua:steam" })
--      (the workspace_rule scopes this layout to ONLY the steam overlay,
--       leaving your normal layout untouched everywhere else)
--   3. Reload Hyprland, enable the setting in the plugin, toggle the overlay.
--
-- The 0.10 / 0.60 / 0.25 split below mirrors the plugin defaults. Edit the
-- ratios here if you change the plugin's width settings.
-- =========================================================================

local FRIENDS_RATIO = 0.10
local MAIN_RATIO    = 0.60
local CHAT_RATIO    = 0.25

local function classify(target)
    local w = target.window
    if not w then
        return "extra"
    end
    local title = w.title or ""
    if title:find("Friends List", 1, true) then
        return "friends"
    end
    if title == "Steam" then
        return "main"
    end
    return "chat"
end

-- Stack a list of targets vertically inside a column.
local function place_column(list, x, w, area)
    local count = #list
    if count == 0 then
        return
    end
    local colH = math.floor(area.h / count)
    for i, target in ipairs(list) do
        target:place({
            x = math.floor(x),
            y = math.floor(area.y + (i - 1) * colH),
            w = math.floor(w),
            h = colH,
        })
    end
end

hl.layout.register("steam", {
    recalculate = function(ctx)
        local targets = ctx.targets
        local n = #targets
        if n == 0 then
            return
        end

        local area = ctx.area
        local used = FRIENDS_RATIO + MAIN_RATIO + CHAT_RATIO
        local margin = math.max(0.0, 1.0 - used) / 2.0

        local friendsX = area.x + area.w * margin
        local mainX    = friendsX + area.w * FRIENDS_RATIO
        local chatX    = mainX + area.w * MAIN_RATIO

        -- A single window: center it at main width.
        if n == 1 then
            targets[1]:place({
                x = math.floor(mainX),
                y = math.floor(area.y),
                w = math.floor(area.w * MAIN_RATIO),
                h = math.floor(area.h),
            })
            return
        end

        local friends, main, chat, extra = {}, {}, {}, {}
        for _, target in ipairs(targets) do
            local kind = classify(target)
            if kind == "friends" then
                friends[#friends + 1] = target
            elseif kind == "main" then
                main[#main + 1] = target
            elseif kind == "chat" then
                chat[#chat + 1] = target
            else
                extra[#extra + 1] = target
            end
        end

        place_column(friends, friendsX, area.w * FRIENDS_RATIO, area)
        place_column(main,    mainX,    area.w * MAIN_RATIO,    area)
        place_column(chat,    chatX,    area.w * CHAT_RATIO,    area)
        -- Unclassified Steam windows share the main column.
        place_column(extra,   mainX,    area.w * MAIN_RATIO,    area)
    end,
})
