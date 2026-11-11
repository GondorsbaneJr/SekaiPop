-- Title bars (hyprbars) only for apps that have none of their own on Hyprland.
-- Add an app: put its class (hyprctl clients) in WANT_BAR.
local WANT_BAR = { "[Ss]potify" }

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
    on_double_click     = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
} } })

-- Right to left: close, maximize, minimize (to the dock, like Super+M).
hl.plugin.hyprbars.add_button({ bg_color = "rgb(f2577f)", fg_color = "rgb(1d1429)", size = 16, icon = "×",
    action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
hl.plugin.hyprbars.add_button({ bg_color = "rgb(b16df2)", fg_color = "rgb(1d1429)", size = 16, icon = "+",
    action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']] })
hl.plugin.hyprbars.add_button({ bg_color = "rgb(7f6bd9)", fg_color = "rgb(1d1429)", size = 16, icon = "–",
    action = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:dockmin", follow = false })']] })

hl.window_rule({ match = { class = ".*" }, ["hyprbars:no_bar"] = true })
for _, cls in ipairs(WANT_BAR) do
    hl.window_rule({ match = { class = "^(" .. cls .. ")$" }, ["hyprbars:no_bar"] = false })
end
