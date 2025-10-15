const std = @import("std");

extern var uniforms: extern struct {
    transform: Mat4,
} addrspace(.uniform);

extern var position_in: @Vector(3, f32) addrspace(.input);
extern var tex_coord_in: @Vector(2, f32) addrspace(.input);

extern var tex_coord_out: @Vector(2, f32) addrspace(.output);

const Mat4 = extern struct {
    c: [4]@Vector(4, f32),

    pub fn mulVec(a: Mat4, b: @Vector(4, f32)) @Vector(4, f32) {
        const Vec = @Vector(4, f32);
        var sum: Vec = @splat(0);
        inline for (0..4) |i| {
            sum += a.c[i] * @as(Vec, @splat(b[i]));
        }
        return sum;
    }
};

export fn main() callconv(.spirv_vertex) void {
    std.gpu.binding(&uniforms, 1, 0);

    std.gpu.location(&position_in, 0);
    std.gpu.location(&tex_coord_in, 1);

    std.gpu.location(&tex_coord_out, 0);

    std.gpu.position_out.* = uniforms.transform.mulVec(.{ position_in[0], position_in[1], position_in[2], 1 });
    tex_coord_out = tex_coord_in;
}
