hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Shell (more): Edit user keybinds"} )

-- Alt+Tab: switch to the next window on this workspace and raise it.
-- Alt+Shift+Tab goes the other way. (Super+Tab is SekaiPop's overview of every window.)
-- Games: Alt+Tab out of a fullscreen game parks it in the dock (still fullscreen, never
-- tiled or resized). The next Alt+Tab brings it straight back, fullscreen.
local function is_game(w)
    if not w then return false end
    if w.content_type == "game" then return true end
    local c, t = (w.class or ""), (w.title or ""):lower()
    return c:match("^steam_app_") ~= nil or c == "gamescope" or c:lower():match("%.exe$") ~= nil
        or t:match("%.exe$") ~= nil or c:match("^Minecraft") ~= nil
end
local parked, parked_mode = nil, 0

hl.bind("ALT + Tab", function()
    local w = hl.get_active_window()
    if is_game(w) and w.fullscreen > 0 then
        parked, parked_mode = w.address, w.fullscreen
        hl.dispatch(hl.dsp.window.move({ workspace = "special:dockmin", follow = false, window = "address:" .. w.address }))
        return
    end
    if parked then
        local addr, mode = parked, parked_mode
        parked = nil
        local g = hl.get_window("address:" .. addr)
        if g and g.mapped and g.workspace and g.workspace.name == "special:dockmin" then
            local ws = hl.get_active_workspace()
            hl.dispatch(hl.dsp.window.move({ workspace = ws and ws.id or 1, follow = true, window = "address:" .. addr }))
            hl.dispatch(hl.dsp.focus({ window = "address:" .. addr }))
            g = hl.get_window("address:" .. addr)
            if g and g.fullscreen == 0 then
                hl.dispatch(hl.dsp.window.fullscreen({ mode = (mode == 1) and "maximized" or "fullscreen", action = "set", window = "address:" .. addr }))
            end
            return
        end
    end
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end, { repeating = true, description = "Windows: Next window" })
hl.bind("ALT + SHIFT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end, { repeating = true, description = "Windows (more): Previous window" })

-- ######## Separate workspaces per screen ########
-- Each monitor has its own 1-10: DP-4 uses real workspaces 1-10, HDMI-A-2 uses 11-20
-- (the bar shows them as 1-10 on both). Super+N / Super+Alt+N act on the focused screen.
-- Keep in sync with custom/rules.lua and the wsOffset map in SekaiPop's bar/Bar.qml.
local WS_OFFSET = { ["DP-4"] = 0, ["HDMI-A-2"] = 10 }
local function ws_for(i)
    local m = hl.get_active_monitor()
    return (WS_OFFSET[m and m.name or ""] or 0) + i
end
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.unbind("SUPER + " .. key)
    hl.unbind("SUPER + ALT + " .. key)
    hl.bind("SUPER + " .. key, function()
        hl.dispatch(hl.dsp.focus({ workspace = ws_for(i) }))
    end, { description = "Workspaces: Focus workspace # on this screen (1-10)" })
    hl.bind("SUPER + ALT + " .. key, function()
        hl.dispatch(hl.dsp.window.move({ workspace = ws_for(i), follow = false }))
    end, { description = "Windows: Send to workspace # on this screen (1-10)" })
end

-- ######## Minimize to dock ########
-- Hyprland ignores apps' own minimize buttons, so Super+M does it instead: the window goes
-- to SekaiPop's hidden "dockmin" workspace (same as the dock's minimize); click it in the dock to bring it back.
-- The equalizer that used to be on Super+M moves to Super+Ctrl+M.
hl.unbind("SUPER + M")
hl.bind("SUPER + M", hl.dsp.window.move({ workspace = "special:dockmin", follow = false }),
    { description = "Windows: Minimize to dock" })
hl.bind("SUPER + CTRL + M", hl.dsp.exec_cmd("qs -c sekaipop ipc call eq open"),
    { description = "Shell: Toggle equalizer" })

-- Apps' own minimize (–) buttons: the minimize-to-event plugin (~/.local/lib/hyprland-plugins)
-- turns them into this event; send the window to the dock like Super+M does.
hl.on("window.minimize", function(w, minimized)
    if minimized and w and w.address then
        hl.dispatch(hl.dsp.window.move({ workspace = "special:dockmin", follow = false, window = "address:" .. w.address }))
    end
end)
