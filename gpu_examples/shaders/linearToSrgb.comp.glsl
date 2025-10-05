#version 450

layout(local_size_x = 8, local_size_y = 8) in;
layout(set = 0, binding = 0, rgba8) uniform image2D image_in; // Is this correct?
layout(set = 1, binding = 0, rgba8) uniform image2D image_out;

vec3 linearToSrgb(vec3 color) {
    return pow(abs(color), vec3(1 / 2.2));
}

void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    vec4 in_pixel = imageLoad(image_in, coords);
    imageStore(image_out, coords, vec4(linearToSrgb(in_pixel.xyz), 1));
}
