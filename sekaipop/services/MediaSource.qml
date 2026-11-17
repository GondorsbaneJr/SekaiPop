import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// The system side of the media pill (with Bar.qml, one of the only two
// files that talk to the system). Anything that publishes itself over
// MPRIS shows up here: Spotify, mpv, VLC, and browsers — Firefox and
// Chromium-based ones expose YouTube / Twitch / SoundCloud tabs as a
// player through the web Media Session API, so "watching a video on
// YT" works with no extra setup.
//
// Which player is shown when there are several:
//   1. whatever is playing right now (if several, the one that started
//      most recently)
//   2. nothing playing -> the one that was playing last, now paused
//   3. otherwise any paused player with a title
//   4. otherwise nothing -> "Nothing Playing"
Scope {
    id: root

    property var lastStarted: null

    readonly property var player: pickPlayer()

    readonly property bool present: player !== null
    readonly property bool playing: player !== null
        && player.playbackState === MprisPlaybackState.Playing

    readonly property string title: {
        if (player === null)
            return ""
        // A few players report no title at all; name the app instead
        // of showing an empty pill.
        return player.trackTitle !== "" ? player.trackTitle : (player.identity ?? "")
    }
    readonly property string artist: player?.trackArtist ?? ""

    // Cover art from the player; when a browser doesn't hand one over
    // but the tab is a YouTube video, fall back to that video's own
    // thumbnail (mqdefault is 16:9 with no letterbox bars).
    readonly property string artUrl: {
        if (player === null)
            return ""
        const direct = player.trackArtUrl ?? ""
        return direct !== "" ? direct : youtubeThumbnail()
    }

    onArtUrlChanged: console.log("[media] " + title + " | art: " + (artUrl !== "" ? artUrl : "(none)"))

    function youtubeThumbnail() {
        const md = player.metadata
        const url = md ? md["xesam:url"] : undefined
        if (typeof url !== "string")
            return ""
        const m = url.match(/(?:[?&]v=|youtu\.be\/|\/shorts\/)([A-Za-z0-9_-]{11})/)
        return m ? "https://i.ytimg.com/vi/" + m[1] + "/mqdefault.jpg" : ""
    }

    function pickPlayer() {
        const list = Mpris.players.values
        const isPlaying = p => p.playbackState === MprisPlaybackState.Playing

        // Rule 1: whatever is playing right now. If several are, the one that
        // started most recently.
        if (lastStarted !== null && list.indexOf(lastStarted) >= 0 && isPlaying(lastStarted))
            return lastStarted
        for (let i = 0; i < list.length; i++) {
            if (isPlaying(list[i]))
                return list[i]
        }

        // Rule 2: nothing is playing -> the one that played last (paused), so
        // pausing Spotify keeps Spotify on the card instead of an old tab.
        if (lastStarted !== null && list.indexOf(lastStarted) >= 0 && lastStarted.trackTitle !== "")
            return lastStarted

        // Rule 3: any paused player with a title, else nothing.
        for (let i = 0; i < list.length; i++) {
            if (list[i].trackTitle !== "")
                return list[i]
        }
        return null
    }

    // Right after the shell (re)starts nothing has "started" yet, so a player that
    // was already playing would lose the pick the moment it is paused (rule 3 then
    // takes the first paused player in the list, maybe an old browser tab). Count
    // whatever is playing at start as the last one started.
    Component.onCompleted: {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing) {
                root.lastStarted = list[i]
                break
            }
        }
    }

    // Remember whichever player last switched to Playing.
    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property var modelData
            target: modelData

            function onPlaybackStateChanged() {
                if (modelData.playbackState === MprisPlaybackState.Playing) {
                    root.lastStarted = modelData
                    return
                }
                // It stopped: if nothing else is playing, it was the last thing playing,
                // so the card keeps it (paused) rather than an older paused player.
                const list = Mpris.players.values
                for (let i = 0; i < list.length; i++) {
                    if (list[i].playbackState === MprisPlaybackState.Playing)
                        return
                }
                root.lastStarted = modelData
            }
        }
    }

    // The wheel over the pill changes the player's own volume (MPRIS
    // Volume, 0..1), five points a notch. Players without volume support
    // (some browsers) ignore it.
    function changeVolume(direction) {
        if (player === null || !player.volumeSupported || !player.canControl)
            return
        const v = Math.max(0, Math.min(1, (player.volume ?? 0) + direction * 0.05))
        player.volume = v
    }

    readonly property bool volumeAvailable: player !== null && player.volumeSupported

    function togglePlaying() {
        if (player !== null && player.canTogglePlaying)
            player.togglePlaying()
    }

    function next() {
        if (player !== null && player.canGoNext)
            player.next()
    }

    function previous() {
        if (player !== null && player.canGoPrevious)
            player.previous()
    }
}
