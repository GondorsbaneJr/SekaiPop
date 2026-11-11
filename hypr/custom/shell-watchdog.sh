#!/bin/sh
# SekaiPop shell watchdog. The lockscreen IS the shell (qs), so if qs dies while the
# screen is locked Hyprland shows "the lockscreen app died" and you need a TTY to get
# back in. This notices qs is gone, saves its logs (they live in /run and are lost on
# reboot), starts it again and locks again, so the new shell takes the lock back
# (misc.allow_session_lock_restore = true in hyprland/general.lua).
#
# Started from custom/execs.lua. Restarts from Settings/updates (restart-shell.sh) are
# left alone: they bring a new qs up within ~5 s, and this waits longer than that.

LOGS="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop/shell-crashes"
QSRUN="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/by-id"

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/sekaipop-shell-watchdog.lock"
flock -n 9 || exit 0   # already running

running() { pgrep -u "$(id -u)" -f '^qs .*sekaipop' >/dev/null; }

while :; do
    sleep 3
    running && continue
    # Gone. Give a deliberate restart time to finish.
    sleep 8
    running && continue
    [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && hyprctl version >/dev/null 2>&1 || exit 0  # session over

    stamp=$(date +%Y-%m-%d_%H-%M-%S)
    mkdir -p "$LOGS/$stamp"
    last=$(ls -td "$QSRUN"/*/ 2>/dev/null | head -1)
    [ -n "$last" ] && cp "$last"log.log "$LOGS/$stamp/qs.log" 2>/dev/null
    hl="${XDG_RUNTIME_DIR}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log"
    [ -f "$hl" ] && tail -n 400 "$hl" > "$LOGS/$stamp/hyprland.log"
    coredumpctl list --no-pager --since "-10min" 2>/dev/null | grep -w qs > "$LOGS/$stamp/coredumps.txt"
    journalctl --user --no-pager --since "-10min" 2>/dev/null | tail -n 300 > "$LOGS/$stamp/journal.txt"
    ls -1d "$LOGS"/*/ 2>/dev/null | head -n -20 | xargs -r rm -rf   # keep the last 20

    setsid prlimit --nofile=65536:1048576 qs -c sekaipop -n -d >/dev/null 2>&1 </dev/null
    # Lock again once its IPC answers (harmless if it wasn't locked: you just unlock).
    i=0
    until qs -c sekaipop ipc call lock lock >/dev/null 2>&1 || [ $i -ge 30 ]; do sleep 1; i=$((i+1)); done
    notify-send -a SekaiPop "Shell restarted" "It stopped unexpectedly. Logs: $LOGS/$stamp" 2>/dev/null
done
