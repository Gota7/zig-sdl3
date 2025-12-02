#version 450

layout(set = 1, binding = 0, std140) uniform uniforms {
    mat4 transform;
};

layout(location = 0) in vec4 position_in;
layout(location = 1) in vec2 tex_coord_in;
layout(location = 2) in vec4 color_in;

layout(location = 0) out vec2 tex_coord_out;
layout(location = 1) out vec4 color_out;

void main() {
    gl_Position = transform * position_in;
    tex_coord_out = tex_coord_in;
    color_out = color_in;
}
