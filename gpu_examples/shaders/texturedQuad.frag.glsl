#version 450

// https://wiki.libsdl.org/SDL3/SDL_CreateGPUShader
layout(set = 2, binding = 0) uniform sampler2D tex0;

layout(location = 0) in vec2 tex_coord_in;

layout(location = 0) out vec4 color_out;

void main() {
    color_out = texture(tex0, tex_coord_in);
}
