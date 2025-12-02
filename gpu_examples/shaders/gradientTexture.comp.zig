const common = @import("common.zig");
const std = @import("std");

const image_out = common.Texture2dRgba8(1, 0);

extern var uniforms: extern struct {
    time: f32,
} addrspace(.uniform);

export fn main() callconv(.spirv_kernel) void {
    // std.gpu.executionMode(main, .{ .local_size = .{ .x = 8, .y = 8, .z = 1 } }); // Set in build system by `spriv_execution_mode`.

    std.gpu.binding(&uniforms, 2, 0);

    const image_sizei = image_out.size();
    const image_size = @Vector(2, f32){ @floatFromInt(image_sizei[0]), @floatFromInt(image_sizei[1]) };
    const uvi = @Vector(2, u32){ std.gpu.global_invocation_id[0], std.gpu.global_invocation_id[1] };
    const uv = @Vector(2, f32){
        @as(f32, @floatFromInt(uvi[0])) / image_size[0],
        @as(f32, @floatFromInt(uvi[1])) / image_size[1],
    };

    const half_vec = @as(@Vector(3, f32), @splat(0.5));
    const color = half_vec + (common.cos((@as(@Vector(3, f32), @splat(uniforms.time)) + @Vector(3, f32){ uv[0], uv[1], uv[0] }) + @Vector(3, f32){ 0, 2, 4 }) * half_vec);
    image_out.store(uvi, .{ color[0], color[1], color[2], 1 });
}
