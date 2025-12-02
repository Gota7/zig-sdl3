#version 450

layout(location = 0) in vec3 position_in;
layout(location = 1) in vec2 tex_coord_in;

layout(location = 0) out vec2 tex_coord_out;

void main() {
    gl_Position = vec4(position_in, 1);
    tex_coord_out = tex_coord_in;
}
