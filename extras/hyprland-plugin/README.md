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

Apps like Spotify draw no title bar of their own and expect the window manager to draw
one, so on Hyprland there is nothing to drag. `hypr/custom/titlebars.lua` gives only the
apps listed in `WANT_BAR` a bar from the official hyprbars plugin, themed for SekaiPop,
with minimize-to-dock, maximize and close buttons.

`hyprbars-sekaipop.patch` (against hyprland-plugins `d2427d4`) makes a bar drag start the
same kind of drag as an app's own title bar, so minimize-to-event floats and snaps it.

Build (Hyprland 0.57.1), then copy `hyprbars.so` to `~/.local/lib/hyprland-plugins/`:

    git clone https://github.com/hyprwm/hyprland-plugins && cd hyprland-plugins
    git checkout d2427d4 && git apply /path/to/hyprbars-sekaipop.patch && cd ..
    cp sdegler-hyprland.repo build-hyprbars-in-container.sh /some/build/dir/
    podman run --rm -v $PWD:/src:Z -v /some/build/dir:/build:Z fedora:45 bash /build/build-hyprbars-in-container.sh
