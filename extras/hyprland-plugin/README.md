# minimize-to-event (Hyprland 0.57.1 plugin)

- App minimize (–) buttons send a `window.minimize` event (Hyprland otherwise drops them);
  `~/.config/hypr/custom/keybinds.lua` moves the window to `special:dockmin` (the dock).
- Dragging a tiled or maximized window by its own title bar floats it under the cursor
  (85% of its tiled size, 640x420 to 75% of the screen). Works for X11 apps too: Hyprland
  0.57.1 ignores X11 `_NET_WM_MOVERESIZE`, so the plugin handles it (title-bar moves and edge resizes).
- Dropping a floating window at a screen's top edge maximizes it; left/right edge fills that half.

Build (Fedora 45, needs podman), from this folder:

    podman run --rm -v "$PWD":/src:Z registry.fedoraproject.org/fedora:45 bash /src/build-in-container.sh
    install -D minimize-to-event.so ~/.local/lib/hyprland-plugins/minimize-to-event.so

Loaded at login by `~/.config/hypr/custom/execs.lua`. Rebuild after every Hyprland update.

## Title bars (hyprbars)

Many Wayland apps (Qt, GTK3, kitty, Spotify) draw no title bar and ask the window manager
to draw one, so on Hyprland there is nothing to drag. The official hyprbars plugin, themed
in `hypr/custom/titlebars.lua` with minimize-to-dock, maximize and close buttons, draws one.

`hyprbars-sekaipop.patch` (against hyprland-plugins `d2427d4`):
- a bar only for windows that asked for server-side decorations (xdg-decoration or KDE
  server-decoration); `WANT_BAR` / `NO_BAR` in titlebars.lua override that per app;
- `floating_bar_opacity`: floating windows get a see-through bar (0.1 here);
- a bar drag starts the same kind of drag as an app's own title bar, so minimize-to-event
  floats and snaps it.

Never `hyprctl plugin unload` hyprbars in a running session: windows keep its bars and
Hyprland crashes on the next frame. Install the new .so and log out and back in.

Build (Hyprland 0.57.1), then copy `hyprbars.so` to `~/.local/lib/hyprland-plugins/`:

    git clone https://github.com/hyprwm/hyprland-plugins && cd hyprland-plugins
    git checkout d2427d4 && git apply /path/to/hyprbars-sekaipop.patch && cd ..
    cp sdegler-hyprland.repo build-hyprbars-in-container.sh /some/build/dir/
    podman run --rm -v $PWD:/src:Z -v /some/build/dir:/build:Z fedora:45 bash /build/build-hyprbars-in-container.sh
