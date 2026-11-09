// minimize-to-event: Hyprland drops apps' own "minimize" requests (title-bar – buttons).
// This listens to every window's state requests and re-sends a minimize request as the
// same "minimize" event a taskbar's minimize produces (Lua hl.on("window.minimize") and
// socket2 "minimized>>"), so the config decides what minimizing does.
#include <any>
#include <sstream>
#include <hyprland/src/plugins/PluginAPI.hpp>
// Everything XWM.hpp includes first, so the #define below reaches only XWM.hpp itself.
#include <hyprland/src/xwayland/XDataSource.hpp>
#include <hyprland/src/xwayland/Dnd.hpp>
#include <hyprland/src/xwayland/XSurface.hpp>
#include <hyprland/src/helpers/memory/Memory.hpp>
#include <hyprland/src/helpers/signal/Signal.hpp>
#include <xcb/xcb.h>
#include <xcb/res.h>
#include <xcb/xfixes.h>
#include <xcb/composite.h>
#include <xcb/xcb_errors.h>
#include <hyprutils/os/FileDescriptor.hpp>
// XWM keeps its XID -> surface lookup private; open it up for this one header.
#define private public
#include <hyprland/src/xwayland/XWM.hpp>
#undef private
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowBackend.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/ipc/s2/S2.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/layout/supplementary/DragController.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/state/MonitorState.hpp>
#include <hyprland/src/state/MonitorQuery.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/xwayland/XWayland.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <unordered_map>
#include <cstring>
#include <cstdlib>
#include <format>
#include <vector>
#include <utility>

using namespace Desktop::View;

inline HANDLE PHANDLE = nullptr;

static auto makeListener(PHLWINDOW w) {
    PHLWINDOWREF ref = w;
    return w->backend().m_events.stateRequest.listen([ref](const SBackendStateRequest& request) {
        if (!request.minimized.has_value() || !request.minimized.value())
            return;
        // Later, not inside the protocol handler: the config's listener moves the window.
        g_pEventLoopManager->doLater([ref] {
            const auto w = ref.lock();
            if (!w || !w->mapped())
                return;
            IPC::Socket2::sock()->postEvent({.event = "minimized", .data = std::format("{:x},1", reinterpret_cast<uintptr_t>(w.get()))});
            Event::bus()->m_events.window.minimize.emit(w, true);
        });
    });
}

using StateListener = decltype(makeListener(PHLWINDOW{}));
inline std::vector<std::pair<PHLWINDOWREF, StateListener>> g_listeners;
inline decltype(Event::bus()->m_events.window.open.listen([](PHLWINDOW) {})) g_openListener;

static void watch(PHLWINDOW w) {
    if (!w)
        return;
    std::erase_if(g_listeners, [](const auto& p) { return !p.first.lock(); });
    for (const auto& p : g_listeners)
        if (p.first.lock() == w)
            return;
    g_listeners.emplace_back(w, makeListener(w));
}

// ===== KDE-style dragging on top of tiling =====
// - Dragging a window by its own title bar (a client move request) pops a tiled or maximized
//   window out into a floating one under the cursor. Super+drag keeps tiling's swap behaviour.
// - Dropping a floating window with the cursor on a screen's top edge maximizes it; on the
//   left/right edge it fills that half. Dragging a snapped window out restores its old size.
inline CFunctionHook* g_beginHook = nullptr;
inline CFunctionHook* g_endHook   = nullptr;
inline std::unordered_map<void*, Vector2D> g_preSnapSize; // window ptr -> floating size before a snap

using beginFn = void (*)(void*, SP<Layout::ITarget>, eMouseBindMode, std::optional<Layout::eRectCorner>, bool);
using endFn   = bool (*)(void*);

static void hkBeginDrag(void* thisptr, SP<Layout::ITarget> target, eMouseBindMode mode, std::optional<Layout::eRectCorner> edge, bool clientDrag) {
    const auto w = target ? target->window() : nullptr;
    if (w && mode == MBIND_MOVE && clientDrag) {
        const auto cursor     = g_pInputManager->getMouseCoordsInternal();
        const CBox before     = target->position();
        bool       popOut     = false;
        const auto snapped    = g_preSnapSize.find(w.get());
        Vector2D   size       = {};

        if (Fullscreen::controller()->isFullscreen(w, Fullscreen::FSMODE_FULLSCREEN))
            return (*(beginFn)g_beginHook->m_original)(thisptr, target, mode, edge, clientDrag); // real fullscreen: leave alone
        if (Fullscreen::controller()->isFullscreen(w, Fullscreen::FSMODE_MAXIMIZED)) {
            Fullscreen::controller()->setFullscreenMode(w, Fullscreen::FSMODE_NONE, Fullscreen::FSMODE_NONE);
            popOut = true;
        }
        if (!target->floating()) {
            g_layoutManager->changeFloatingMode(target);
            popOut = true;
        }
        if (snapped != g_preSnapSize.end()) {
            size   = snapped->second;
            popOut = true;
            g_preSnapSize.erase(snapped);
        }
        if (popOut && target->floating()) {
            // Pop-out size: a snapped window gets its old size back; otherwise 85% of the size
            // it had while tiled / maximized, kept between 640x420 and 75% of the monitor's free area.
            if (size.x <= 1 || size.y <= 1)
                size = before.size() * 0.85;
            if (const auto mon = State::monitorState()->query().vec(cursor).run(); mon) {
                const CBox work = mon->logicalBoxMinusReserved();
                size.x          = std::clamp(size.x, std::min(640.0, work.w), work.w * 0.75);
                size.y          = std::clamp(size.y, std::min(420.0, work.h), work.h * 0.75);
            }
            const double relX = before.w > 0 ? std::clamp((cursor.x - before.x) / before.w, 0.0, 1.0) : 0.5;
            const double offY = std::clamp(cursor.y - before.y, 8.0, 40.0);
            g_layoutManager->setTargetGeom(CBox{cursor.x - size.x * relX, cursor.y - offY, size.x, size.y}, target);
        }
    }
    (*(beginFn)g_beginHook->m_original)(thisptr, target, mode, edge, clientDrag);
}

static bool hkEndDrag(void* thisptr) {
    const auto& DC     = g_layoutManager->dragController();
    const auto  target = DC ? DC->target() : nullptr;
    const auto  mode   = DC ? DC->mode() : MBIND_INVALID;
    const bool  ret    = (*(endFn)g_endHook->m_original)(thisptr);

    const auto  w = target ? target->window() : nullptr;
    if (!w || mode != MBIND_MOVE || !target->floating() || !w->mapped())
        return ret;

    const auto cursor = g_pInputManager->getMouseCoordsInternal();
    const auto mon    = State::monitorState()->query().vec(cursor).run();
    if (!mon)
        return ret;
    const CBox   box  = mon->logicalBox();
    const CBox   work = mon->logicalBoxMinusReserved();
    const double E = 3, G = 10;
    const auto   remember = [&] {
        if (!g_preSnapSize.contains(w.get()))
            g_preSnapSize[w.get()] = target->position().size();
    };

    if (cursor.y <= box.y + E) {
        remember();
        Fullscreen::controller()->setFullscreenMode(w, Fullscreen::FSMODE_MAXIMIZED, Fullscreen::FSMODE_MAXIMIZED);
    } else if (cursor.x <= box.x + E) {
        remember();
        g_layoutManager->setTargetGeom(CBox{work.x + G, work.y + G, work.w / 2 - G * 1.5, work.h - G * 2}, target);
    } else if (cursor.x >= box.x + box.w - E) {
        remember();
        g_layoutManager->setTargetGeom(CBox{work.x + work.w / 2 + G * 0.5, work.y + G, work.w / 2 - G * 1.5, work.h - G * 2}, target);
    }
    return ret;
}

// ===== X11 apps: title-bar move / edge resize =====
// Hyprland 0.57.1 advertises _NET_WM_MOVERESIZE but never handles it, so dragging an X11 app's
// own title bar (Electron apps under XWayland, Steam, ...) does nothing. Handle it like the
// Wayland move/resize request: start a client drag on the window under the cursor.
inline CFunctionHook* g_clientMsgHook = nullptr;
inline xcb_atom_t     g_moveResizeAtom = XCB_ATOM_NONE;
using clientMsgFn = void (*)(void*, xcb_client_message_event_t*);

static void hkClientMessage(void* thisptr, xcb_client_message_event_t* e) {
    // Hyprland's own atom table (exported, so this reads the copy XWM filled in).
    if (g_moveResizeAtom == XCB_ATOM_NONE) {
        if (const auto it = HYPRATOMS.find("_NET_WM_MOVERESIZE"); it != HYPRATOMS.end())
            g_moveResizeAtom = it->second;
    }
    if (e && g_moveResizeAtom != XCB_ATOM_NONE && e->type == g_moveResizeAtom && e->format == 32) {
        const uint32_t dir = e->data.data32[2];
        if (dir <= 8) {
            // The window that sent the request (the message names its XID).
            PHLWINDOW  w;
            const auto xsurf = static_cast<CXWM*>(thisptr)->windowForXID(e->window);
            const auto wlsurf = xsurf ? xsurf->m_surface.lock() : nullptr;
            if (wlsurf)
                for (const auto& cand : Desktop::windowState()->windows())
                    if (cand && cand->backend().isX11() && cand->backend().surface() == wlsurf) {
                        w = cand;
                        break;
                    }
            if (w && w->backend().isX11() && w->mapped() && !g_layoutManager->dragController()->target()) {
                static const Layout::eRectCorner corners[8] = {Layout::CORNER_TOPLEFT, Layout::CORNER_TOP,    Layout::CORNER_TOPRIGHT,   Layout::CORNER_RIGHT,
                                                               Layout::CORNER_BOTTOMRIGHT, Layout::CORNER_BOTTOM, Layout::CORNER_BOTTOMLEFT, Layout::CORNER_LEFT};
                if (dir == 8)
                    g_layoutManager->beginDragTarget(w->layoutTarget(), MBIND_MOVE, std::nullopt, true);
                else
                    g_layoutManager->beginDragTarget(w->layoutTarget(), MBIND_RESIZE, corners[dir], true);
                return;
            }
        }
    }
    (*(clientMsgFn)g_clientMsgHook->m_original)(thisptr, e);
}

static CFunctionHook* hookByName(const std::string& name, const std::string& demangledPart, void* fn) {
    for (const auto& m : HyprlandAPI::findFunctionsByName(PHANDLE, name)) {
        if (m.demangled.find(demangledPart) == std::string::npos)
            continue;
        auto h = HyprlandAPI::createFunctionHook(PHANDLE, m.address, fn);
        if (h && h->hook())
            return h;
    }
    HyprlandAPI::addNotification(PHANDLE, "[minimize-to-event] could not hook " + demangledPart, CHyprColor{1.0, 0.3, 0.3, 1.0}, 8000);
    return nullptr;
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE         = handle;
    g_openListener  = Event::bus()->m_events.window.open.listen([](PHLWINDOW w) { watch(w); });
    for (const auto& w : Desktop::windowState()->windows())
        watch(w);
    g_beginHook = hookByName("beginDragTarget", "CLayoutManager::beginDragTarget", (void*)&hkBeginDrag);
    g_endHook   = hookByName("endDragTarget", "CLayoutManager::endDragTarget", (void*)&hkEndDrag);
    g_clientMsgHook = hookByName("handleClientMessage", "CXWM::handleClientMessage", (void*)&hkClientMessage);
    return {"minimize-to-event", "App minimize buttons -> window.minimize; KDE-style title-bar drag and edge snapping", "local", "2.1"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_listeners.clear();
    if (g_beginHook)
        HyprlandAPI::removeFunctionHook(PHANDLE, g_beginHook);
    if (g_endHook)
        HyprlandAPI::removeFunctionHook(PHANDLE, g_endHook);
    if (g_clientMsgHook)
        HyprlandAPI::removeFunctionHook(PHANDLE, g_clientMsgHook);
    g_openListener = {};
}
