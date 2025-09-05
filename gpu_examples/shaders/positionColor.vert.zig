const std = @import("std");

extern var position_in: @Vector(3, f32) addrspace(.input);
extern var color_in: @Vector(4, f32) addrspace(.input);

extern var color_out: @Vector(4, f32) addrspace(.output);

export fn main() callconv(.spirv_vertex) void {
    std.gpu.location(&position_in, 0);
    std.gpu.location(&color_in, 1);

    std.gpu.location(&color_out, 0);

    std.gpu.position_out.* = .{ position_in[0], position_in[1], position_in[2], 1 };
    color_out = color_in;
}
