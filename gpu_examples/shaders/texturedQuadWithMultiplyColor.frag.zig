const common = @import("common.zig");
const std = @import("std");

const tex0 = common.Sampler2d(2, 0);

extern var uniforms: extern struct {
    multiply_color: @Vector(4, f32),
} addrspace(.uniform);

extern var tex_coord_in: @Vector(2, f32) addrspace(.input);

extern var color_out: @Vector(4, f32) addrspace(.output);

export fn main() callconv(.spirv_fragment) void {
    std.gpu.binding(&uniforms, 3, 0);

    std.gpu.location(&tex_coord_in, 0);

    std.gpu.location(&color_out, 0);

    color_out = uniforms.multiply_color * tex0.texture(tex_coord_in);
}
