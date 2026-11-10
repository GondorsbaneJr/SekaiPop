-- Your own changes. Loaded after the defaults in hyprland/general.lua; never overwritten.

-- KDE-style magnetic snapping while dragging a floating window: its edges stick to the
-- screen edges (including the edge between the two screens) and to other windows' edges.
-- SekaiPop's 4-5 px was too small to notice on a 4K screen.
hl.config({
    general = {
        snap = {
            enabled = true,
            window_gap = 30,     -- px: how close to another window before it snaps to it
            monitor_gap = 40,    -- px: how close to a screen edge before it snaps to it
            respect_gaps = true, -- keep the normal gap between snapped windows
            border_overlap = false,
        },
    },
})
