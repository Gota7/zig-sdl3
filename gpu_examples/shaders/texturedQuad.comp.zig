const common = @import("common.zig");
const std = @import("std");

const texture_in = common.Sampler2d(0, 0);

const image_out = common.Texture2dRgba8(1, 0);

extern var uniforms: extern struct {
    texcoord_multiplier: f32,
} addrspace(.uniform);

export fn main() callconv(.spirv_kernel) void {
    // std.gpu.executionMode(main, .{ .local_size = .{ .x = 8, .y = 8, .z = 1 } }); // Set in build system by `spriv_execution_mode`.

    std.gpu.binding(&uniforms, 2, 0);

    const image_sizei = texture_in.size(0);
    const image_size = @Vector(2, f32){ @floatFromInt(image_sizei[0]), @floatFromInt(image_sizei[1]) };
    const uvi = @Vector(2, u32){ std.gpu.global_invocation_id[0], std.gpu.global_invocation_id[1] };
    const uv = @Vector(2, f32){
        @as(f32, @floatFromInt(uvi[0])) * uniforms.texcoord_multiplier / image_size[0],
        @as(f32, @floatFromInt(uvi[1])) * uniforms.texcoord_multiplier / image_size[1],
    };
    image_out.store(uvi, texture_in.textureLod(uv, 0));
}
