const std = @import("std");

extern var uniforms: extern struct {
    near_plane: f32,
    far_plane: f32,
} addrspace(.uniform);

extern var color_in: @Vector(4, f32) addrspace(.input);

extern var color_out: @Vector(4, f32) addrspace(.output);

fn linearizeDepth(depth: f32, near: f32, far: f32) f32 {
    const z = depth * 2 - 1;
    return ((2 * near * far) / (far + near - z * (far - near))) / far;
}

export fn main() callconv(.spirv_fragment) void {
    // Unfortunately this is broken currently. However, I hack this functionality in using SPIRV-tools and a custom build tool...
    // std.gpu.executionMode(main, .depth_replacing);
    std.gpu.binding(&uniforms, 3, 0);
    std.gpu.location(&color_in, 0);
    std.gpu.location(&color_out, 0);

    color_out = color_in;
    std.gpu.frag_depth = linearizeDepth(std.gpu.frag_coord[2], uniforms.near_plane, uniforms.far_plane);
}
