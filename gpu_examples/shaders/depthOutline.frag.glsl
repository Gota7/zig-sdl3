#version 450

layout(set = 2, binding = 0) uniform sampler2D color_tex;
layout(set = 2, binding = 1) uniform sampler2D depth_tex;

layout(location = 0) in vec2 tex_coord_in;

layout(location = 0) out vec4 color_out;

// Get the difference between depth value and adjacent depth pixels.
// This is used to detect "edges" where the depth falls off.
float getDifference(float depth, vec2 tex_coord, float distance) {
    vec2 dim = vec2(textureSize(depth_tex, 0));
    return max(texture(depth_tex, tex_coord + vec2(1.0 / dim.x, 0) * distance).r - depth,
        max(texture(depth_tex, tex_coord + vec2(-1.0 / dim.x, 0) * distance).r - depth,
            max(texture(depth_tex, tex_coord + vec2(0, 1.0 / dim.y) * distance).r - depth,
                texture(depth_tex, tex_coord + vec2(0, -1.0 / dim.y) * distance).r - depth)));
}

void main() {

    // Get color and depth.
    vec4 color = texture(color_tex, tex_coord_in);
    float depth = texture(depth_tex, tex_coord_in).r;

    // Get the difference between the edges at 1 and 2 pixels away.
    float edge1 = step(0.2, getDifference(depth, tex_coord_in, 1));
    float edge2 = step(0.2, getDifference(depth, tex_coord_in, 2));

    // Turn inner edges black.
    vec3 res = mix(color.rgb, vec3(0), edge2);

    // Turn outer edges white.
    res = mix(res, vec3(1), edge1);

    // Combine results.
    color_out = vec4(res, color.a);
}
