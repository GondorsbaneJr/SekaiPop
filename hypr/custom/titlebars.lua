-- Title bars (hyprbars) for Wayland apps that ask the window manager to draw one
-- (xdg-decoration / KDE server-decoration: Qt, GTK3, kitty, Spotify...). Apps that draw
-- their own get none. Overrides, by class (hyprctl clients):
local WANT_BAR = { "[Ss]potify" } -- always a bar
local NO_BAR   = { }              -- never a bar

-- Everything here waits for the plugin: until it is loaded these names don't exist yet.
if not (hl.plugin and hl.plugin.hyprbars) then return end

hl.config({ plugin = { hyprbars = {
    bar_height          = 34,
    bar_color           = "rgba(1d1429f2)",
    ["col.text"]        = "rgba(eadcffff)",
    bar_text_size       = 11,
    bar_text_font       = "Sans",
    bar_text_align      = "left",
    bar_padding         = 14,
    bar_button_padding  = 9,
    bar_part_of_window  = true,
    bar_precedence_over_border = true,
    floating_bar_opacity = 0.1, -- floating windows: ~90% see-through bar (tiled/maximized: solid)
    on_double_click     = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
} } })

-- Right to left: close, fullscreen, maximize, minimize (to the dock, like Super+M).
hl.plugin.hyprbars.add_button({ bg_color = "rgb(f2577f)", fg_color = "rgb(1d1429)", size = 16, icon = "×",
    action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
hl.plugin.hyprbars.add_button({ bg_color = "rgb(32cd32)", fg_color = "rgb(1d1429)", size = 16, icon = "⤢",
    action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })']] })
hl.plugin.hyprbars.add_button({ bg_color = "rgb(b16df2)", fg_color = "rgb(1d1429)", size = 16, icon = "+",
    action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']] })
hl.plugin.hyprbars.add_button({ bg_color = "rgb(7f6bd9)", fg_color = "rgb(1d1429)", size = 16, icon = "–",
    action = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:dockmin", follow = false })']] })

for _, cls in ipairs(WANT_BAR) do
    hl.window_rule({ match = { class = "^(" .. cls .. ")$" }, ["hyprbars:no_bar"] = false })
end
for _, cls in ipairs(NO_BAR) do
    hl.window_rule({ match = { class = "^(" .. cls .. ")$" }, ["hyprbars:no_bar"] = true })
end
