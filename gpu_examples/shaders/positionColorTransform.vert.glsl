#version 450

layout(set = 1, binding = 0, std140) uniform uniforms {
    mat4 transform;
};

layout(location = 0) in vec3 position_in;
layout(location = 1) in vec4 color_in;

layout(location = 0) out vec4 color_out;

void main() {
    gl_Position = transform * vec4(position_in, 1);
    color_out = color_in;
}
