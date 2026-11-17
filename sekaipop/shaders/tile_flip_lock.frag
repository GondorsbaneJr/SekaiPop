#version 440

// Tile flip, lockscreen edition (LockRing.qml, style "tileFlip").
//
// The screen is cut into square tiles. Each tile is a card: one side is the
// desktop, the other the lockscreen. The cards spin 180 degrees around their
// upright middle line, one after another in a diagonal wave from the
// top-left corner, with real perspective, and darken while edge-on.
//
//   source0   a still of the desktop, taken the moment the lock started
//   source1   the lockscreen picture (premultiplied)
//
// Tiles that have not started yet (locking) or have landed (unlocking) are
// left transparent, so the LIVE desktop shows there; the still is only seen
// on cards that are turning.
//
//   unlocking = 0   desktop -> lockscreen
//   unlocking = 1   lockscreen -> desktop
//
// progress runs 0..1 Linear; each card eases itself.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    int unlocking;
    vec2 res;        // the window's size in pixels
    float tilePx;    // one tile's side in pixels
} ubuf;

layout(binding = 1) uniform sampler2D source0; // desktop still
layout(binding = 2) uniform sampler2D source1; // lockscreen

const float PI = 3.14159265;
const float STAGGER = 0.13;   // delay per diagonal step, in card-flip lengths
const float DEPTH = 5.0;      // eye distance, in tiles (smaller = stronger perspective)
const float SHADE = 0.85;     // how dark a card gets edge-on
const vec4 GAP = vec4(0.02, 0.025, 0.03, 1.0); // seen around a turning card

float easeInOut(float x) {
    return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0;
}

vec4 desk(vec2 uv) { return vec4(texture(source0, uv).rgb, 1.0); }
vec4 lock(vec2 uv) { return texture(source1, uv); }

void main() {
    bool leaving = ubuf.unlocking != 0;
    float tp = max(ubuf.tilePx, 8.0);
    vec2 px = qt_TexCoord0 * ubuf.res;
    vec2 cell = floor(px / tp);
    vec2 grid = ceil(ubuf.res / tp);
    float steps = max(grid.x + grid.y - 2.0, 1.0);

    float t = clamp(ubuf.progress, 0.0, 1.0) * (steps * STAGGER + 1.0);
    float lp = clamp(t - (cell.x + cell.y) * STAGGER, 0.0, 1.0);

    // Not turned yet / already landed: flat.
    if (lp <= 0.0) {
        fragColor = (leaving ? lock(qt_TexCoord0) : vec4(0.0)) * ubuf.qt_Opacity;
        return;
    }
    if (lp >= 1.0) {
        fragColor = (leaving ? vec4(0.0) : lock(qt_TexCoord0)) * ubuf.qt_Opacity;
        return;
    }

    float a = easeInOut(lp) * PI;
    float ca = cos(a), sa = sin(a);
    vec2 centre = (cell + 0.5) * tp;
    vec2 q = (px - centre) / tp;            // this pixel, in tile units around the middle

    // Which point (u, v) of the turned card lands on this pixel.
    float denom = DEPTH * ca - q.x * sa;
    vec4 col = GAP;
    if (abs(denom) > 1e-4) {
        float u = q.x * DEPTH / denom;
        float v = q.y * (DEPTH + u * sa) / DEPTH;
        if (abs(u) <= 0.5 && abs(v) <= 0.5 && (DEPTH + u * sa) > 0.0) {
            bool front = ca > 0.0;
            vec2 card = front ? vec2(u, v) : vec2(-u, v);
            vec2 uv = clamp((centre + card * tp) / ubuf.res, 0.0, 1.0);
            vec4 c;
            if (front) c = leaving ? lock(uv) : desk(uv);
            else       c = leaving ? desk(uv) : lock(uv);
            float shade = sa * SHADE;
            col = vec4(c.rgb * (1.0 - shade), c.a);
        }
    }
    fragColor = col * ubuf.qt_Opacity;
}
