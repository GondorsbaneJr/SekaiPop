-- Your own changes. Loaded after the defaults in hyprland/execs.lua; never overwritten.

-- Apps' own minimize (–) buttons -> the dock. Plugin built for Hyprland 0.57.1; after a
-- Hyprland update it refuses to load (nothing breaks, the buttons just stop working) and
-- needs rebuilding from ~/.local/lib/hyprland-plugins/minimize-to-event.cpp.
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl plugin load " .. os.getenv("HOME") .. "/.local/lib/hyprland-plugins/minimize-to-event.so")
end)
