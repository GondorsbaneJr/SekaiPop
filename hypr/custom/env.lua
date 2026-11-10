-- Your own changes. Loaded after the defaults in hyprland/env.lua; never overwritten.

-- App icons in the launcher/dock: Quickshell has no icon theme outside Plasma.
hl.env("QS_ICON_THEME", "breeze-dark")

-- NVIDIA: use egl-wayland (1.x) instead of egl-wayland2. egl-wayland2 1.0.2 never handles the
-- wl_buffer.release events it asks for, so every frame an app draws leaks a little memory
-- (Quickshell reached 6 GB in 14 hours). Remove this once a fixed egl-wayland2 ships.
local EGL_D = "/usr/share/egl/egl_external_platform.d/"
hl.env("__EGL_EXTERNAL_PLATFORM_CONFIG_FILENAMES", table.concat({
    EGL_D .. "10_nvidia_wayland.json", EGL_D .. "15_nvidia_gbm.json",
    EGL_D .. "20_nvidia_xcb.json", EGL_D .. "20_nvidia_xlib.json" }, ":"))
