const common = @import("common.zig");
const std = @import("std");

const tex0 = common.Sampler2dArray(2, 0);

extern var tex_coord_in: @Vector(2, f32) addrspace(.input);

extern var color_out: @Vector(4, f32) addrspace(.output);

export fn main() callconv(.spirv_fragment) void {
    std.gpu.location(&tex_coord_in, 0);

    std.gpu.location(&color_out, 0);

    color_out = tex0.texture(.{
        tex_coord_in[0],
        tex_coord_in[1],
        if (tex_coord_in[1] > 0.5) 1 else 0,
    });
}
