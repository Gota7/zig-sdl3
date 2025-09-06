#version 450

layout(location = 0) in vec3 position_in;
layout(location = 1) in vec4 color_in;

layout(location = 0) out vec4 color_out;

void main() {
    color_out = color_in;
    vec3 pos = (position_in * 0.25) - vec3(0.75, 0.75, 0.0);
    pos.x += float(gl_InstanceIndex % 4) * 0.5f;
    pos.y += floor(float(gl_InstanceIndex / 4)) * 0.5f;
    gl_Position = vec4(pos, 1.0f);
}
