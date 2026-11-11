-- Your own changes. Loaded after the defaults in hyprland/execs.lua; never overwritten.

-- Apps' own minimize (–) buttons -> the dock. Plugin built for Hyprland 0.57.1; after a
-- Hyprland update it refuses to load (nothing breaks, the buttons just stop working) and
-- needs rebuilding from ~/.local/lib/hyprland-plugins/minimize-to-event.cpp.
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl plugin load " .. os.getenv("HOME") .. "/.local/lib/hyprland-plugins/minimize-to-event.so")
end)

-- If the shell (and with it the lockscreen) dies, start it again and re-lock, and keep its
-- logs in ~/.local/state/sekaipop/shell-crashes. See custom/shell-watchdog.sh.
hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/custom/shell-watchdog.sh")
end)

-- Title bars for apps that expect the window manager to draw one (Spotify): hyprbars, built
-- for Hyprland 0.57.1 from hyprland-plugins d2427d4 + hyprbars-sekaipop.patch (bar drags float
-- and snap like app title bars). Which apps get a bar: custom/titlebars.lua.
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl plugin load " .. os.getenv("HOME") .. "/.local/lib/hyprland-plugins/hyprbars.so")
end)
