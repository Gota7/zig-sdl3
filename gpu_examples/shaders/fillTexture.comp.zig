const common = @import("common.zig");
const std = @import("std");

const image_out = common.Texture2dRgba8(1, 0);

export fn main() callconv(.spirv_kernel) void {
    // std.gpu.executionMode(main, .{ .local_size = .{ .x = 8, .y = 8, .z = 1 } }); // Set in build system by `spriv_execution_mode`.

    image_out.store(.{ std.gpu.global_invocation_id[0], std.gpu.global_invocation_id[1] }, .{ 1, 1, 0, 1 });
}
