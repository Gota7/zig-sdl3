const std = @import("std");

extern var color_in: @Vector(4, f32) addrspace(.input);

extern var color_out: @Vector(4, f32) addrspace(.output);

export fn main() callconv(.spirv_fragment) void {
    std.gpu.location(&color_in, 0);
    std.gpu.location(&color_out, 0);

    color_out = color_in;
}
