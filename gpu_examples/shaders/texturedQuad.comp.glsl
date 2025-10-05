#version 450

layout(local_size_x = 8, local_size_y = 8) in;
layout(set = 0, binding = 0) uniform sampler2D texture_in;

layout(set = 1, binding = 0, rgba8) uniform image2D image_out;

layout(set = 2, binding = 0, std140) uniform uniforms {
    float texcoord_multiplier;
};

void main() {
    ivec2 size = textureSize(texture_in, 0);
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    vec2 texcoord = (vec2(coord) * vec2(texcoord_multiplier)) / vec2(size);
    vec4 in_pixel = texture(texture_in, texcoord, 0);
    imageStore(image_out, coord, in_pixel);
}
