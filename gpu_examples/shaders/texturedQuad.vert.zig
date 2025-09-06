const std = @import("std");

extern var position_in: @Vector(3, f32) addrspace(.input);
extern var tex_coord_in: @Vector(2, f32) addrspace(.input);

extern var tex_coord_out: @Vector(2, f32) addrspace(.output);

export fn main() callconv(.spirv_vertex) void {
    std.gpu.location(&position_in, 0);
    std.gpu.location(&tex_coord_in, 1);

    std.gpu.location(&tex_coord_out, 0);

    std.gpu.position_out.* = .{ position_in[0], position_in[1], position_in[2], 1 };
    tex_coord_out = tex_coord_in;
}
