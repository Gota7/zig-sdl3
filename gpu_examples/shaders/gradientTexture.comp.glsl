#version 450

layout(local_size_x = 8, local_size_y = 8) in;
layout(set = 1, binding = 0, rgba8) uniform image2D image_out;
layout(set = 2, binding = 0) uniform uniforms {
    float time;
};

void main() {
    ivec2 image_size = imageSize(image_out);
    vec2 uv = gl_GlobalInvocationID.xy / vec2(image_size);

    vec3 color = vec3(0.5) + (cos((vec3(time) + uv.xyx) + vec3(0, 2, 4)) * 0.5);
    imageStore(image_out, ivec2(gl_GlobalInvocationID.xy), vec4(color, 1));
}
