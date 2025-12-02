#version 450

layout(set = 2, binding = 0) uniform sampler2D tex0;
layout(set = 3, binding = 0, std140) uniform uniforms {
    vec4 multiply_color;
};

layout(location = 0) in vec2 tex_coord_in;

layout(location = 0) out vec4 color_out;

void main() {
    color_out = multiply_color * texture(tex0, tex_coord_in);
}
