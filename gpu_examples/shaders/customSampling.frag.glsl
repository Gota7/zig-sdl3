#version 450

layout(set = 2, binding = 0, rgba8) uniform image2D tex0;
layout(set = 3, binding = 0, std140) uniform uniforms {
    int custom_sampler;
};

layout(location = 0) in vec2 tex_coord_in;

layout(location = 0) out vec4 color_out;

void main() {
    ivec2 size = imageSize(tex0);
    ivec2 texel_pos = ivec2(vec2(size) * tex_coord_in);
    vec4 texel = imageLoad(tex0, texel_pos);
    color_out = texel;
}
