#version 440

// Tile flip, lockscreen edition: vertex boilerplate. The flip itself is in
// tile_flip_lock.frag. The uniform block must match the .frag exactly
// (shaders/README.md).

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    int unlocking;
    vec2 res;
    float tilePx;
} ubuf;

out gl_PerVertex { vec4 gl_Position; };

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}
