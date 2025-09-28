#version 450

layout(set = 2, binding = 0) uniform samplerCube tex0;

layout(location = 0) in vec3 tex_coord_in;

layout(location = 0) out vec4 color_out;

void main() {
    color_out = texture(tex0, tex_coord_in);
}
