#version 450

layout(local_size_x = 8, local_size_y = 8) in;
layout(set = 1, binding = 0, rgba32f) uniform image2D image_out;

void main() {
    imageStore(image_out, ivec2(gl_GlobalInvocationID.xy), vec4(1, 1, 0, 1));
}
