const std = @import("std");

extern var color_out: @Vector(4, f32) addrspace(.output);

export fn main() callconv(.spirv_vertex) void {
    std.gpu.location(&color_out, 0);

    switch (std.gpu.vertex_index) {
        0 => {
            std.gpu.position_out.* = .{ -1, -1, 0, 1 };
            color_out = .{ 1, 0, 0, 1 };
        },
        1 => {
            std.gpu.position_out.* = .{ 1, -1, 0, 1 };
            color_out = .{ 0, 1, 0, 1 };
        },
        else => {
            std.gpu.position_out.* = .{ 0, 1, 0, 1 };
            color_out = .{ 0, 0, 1, 1 };
        },
    }
}
