-- Your own changes. Loaded after the defaults in hyprland/rules.lua; never overwritten.

-- ######## Separate workspaces per screen ########
-- DP-4 owns workspaces 1-10, HDMI-A-2 owns 11-20 (see custom/keybinds.lua).
for i = 1, 10 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-4", default = (i == 1) })
    hl.workspace_rule({ workspace = tostring(i + 10), monitor = "HDMI-A-2", default = (i == 1) })
end

-- ######## Games never tile ########
-- Games float, so losing fullscreen (Alt+Tab, a popup) never squashes them into a tile.
-- Keep the patterns in sync with is_game() in custom/keybinds.lua.
hl.window_rule({ match = { content = "game" },                       float = true })
hl.window_rule({ match = { class = "^(steam_app_.*)$" },             float = true })
hl.window_rule({ match = { class = "^(gamescope)$" },                float = true })
hl.window_rule({ match = { class = "^(.*\\.[eE][xX][eE])$" },        float = true })
hl.window_rule({ match = { title = "^(.*\\.[eE][xX][eE])$" },        float = true })
hl.window_rule({ match = { class = "^(Minecraft.*)$" },              float = true })
