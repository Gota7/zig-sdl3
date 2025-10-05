#version 450

// https://wiki.libsdl.org/SDL3/SDL_CreateGPUShader
layout(set = 2, binding = 0) uniform sampler2DArray tex0;

layout(location = 0) in vec2 tex_coord_in;

layout(location = 0) out vec4 color_out;

void main() {
    float array_index = 0;
    if (tex_coord_in.y > 0.5) {
        array_index = 1;
    }
    color_out = texture(tex0, vec3(tex_coord_in, array_index));
}
