#version 450

layout(set = 2, binding = 0) uniform sampler2D tex0;

layout(location = 0) in vec2 tex_coord_in;
layout(location = 1) in vec4 color_in;

layout(location = 0) out vec4 color_out;

void main() {
    color_out = texture(tex0, tex_coord_in) * color_in;
}
