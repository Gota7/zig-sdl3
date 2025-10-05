const std = @import("std");

extern var uniforms: extern struct {
    transform: Mat4,
} addrspace(.uniform);

extern var position_in: @Vector(3, f32) addrspace(.input);
extern var tex_coord_in: @Vector(2, f32) addrspace(.input);

extern var tex_coord_out: @Vector(2, f32) addrspace(.output);

const Mat4 = extern struct {
    c0: @Vector(4, f32),
    c1: @Vector(4, f32),
    c2: @Vector(4, f32),
    c3: @Vector(4, f32),

    pub fn mulVec(a: Mat4, b: @Vector(4, f32)) @Vector(4, f32) {
        const ar0 = a.row(0);
        const ar1 = a.row(1);
        const ar2 = a.row(2);
        const ar3 = a.row(3);
        return .{ @reduce(.Add, ar0 * b), @reduce(.Add, ar1 * b), @reduce(.Add, ar2 * b), @reduce(.Add, ar3 * b) };
    }

    pub fn row(mat: Mat4, ind: comptime_int) @Vector(4, f32) {
        return switch (ind) {
            0 => .{ mat.c0[0], mat.c1[0], mat.c2[0], mat.c3[0] },
            1 => .{ mat.c0[1], mat.c1[1], mat.c2[1], mat.c3[1] },
            2 => .{ mat.c0[2], mat.c1[2], mat.c2[2], mat.c3[2] },
            3 => .{ mat.c0[3], mat.c1[3], mat.c2[3], mat.c3[3] },
            else => @compileError("Invalid row number"),
        };
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
