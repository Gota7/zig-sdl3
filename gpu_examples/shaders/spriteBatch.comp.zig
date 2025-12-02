// TODO: FIGURE OUT WHY THIS DOESN'T WORK!

const common = @import("common.zig");
const std = @import("std");

const sprites = common.RuntimeArray(0, 0, SpriteComputeData);

const vertices = common.RuntimeArray(1, 0, SpriteVertex);

const SpriteComputeData = extern struct {
    position_rot: @Vector(4, f32), // Rotation should be after this, but having it after messes up the alignment!
    scale: @Vector(2, f32),
    texture: @Vector(4, f32),
    color: @Vector(4, f32),

    comptime {
        std.debug.assert(@offsetOf(SpriteComputeData, "position_rot") == 0);
        // std.debug.assert(@offsetOf(SpriteComputeData, "rotation") == 12);
        std.debug.assert(@offsetOf(SpriteComputeData, "scale") == 16);
        std.debug.assert(@offsetOf(SpriteComputeData, "texture") == 32);
        std.debug.assert(@offsetOf(SpriteComputeData, "color") == 48);
    }
};

const SpriteVertex = extern struct {
    position: @Vector(4, f32),
    tex_coord: @Vector(2, f32),
    color: @Vector(4, f32),

    comptime {
        std.debug.assert(@offsetOf(SpriteVertex, "position") == 0);
        std.debug.assert(@offsetOf(SpriteVertex, "tex_coord") == 16);
        std.debug.assert(@offsetOf(SpriteVertex, "color") == 32);
    }
};

const Mat4 = extern struct {
    c0: @Vector(4, f32),
    c1: @Vector(4, f32),
    c2: @Vector(4, f32),
    c3: @Vector(4, f32),

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        const ar0 = a.row(0);
        const ar1 = a.row(1);
        const ar2 = a.row(2);
        const ar3 = a.row(3);
        return .{
            .c0 = .{ @reduce(.Add, ar0 * b.c0), @reduce(.Add, ar1 * b.c0), @reduce(.Add, ar2 * b.c0), @reduce(.Add, ar3 * b.c0) },
            .c1 = .{ @reduce(.Add, ar0 * b.c1), @reduce(.Add, ar1 * b.c1), @reduce(.Add, ar2 * b.c1), @reduce(.Add, ar3 * b.c1) },
            .c2 = .{ @reduce(.Add, ar0 * b.c2), @reduce(.Add, ar1 * b.c2), @reduce(.Add, ar2 * b.c2), @reduce(.Add, ar3 * b.c2) },
            .c3 = .{ @reduce(.Add, ar0 * b.c3), @reduce(.Add, ar1 * b.c3), @reduce(.Add, ar2 * b.c3), @reduce(.Add, ar3 * b.c3) },
        };
    }

    pub fn mulVec(a: Mat4, b: @Vector(4, f32)) @Vector(4, f32) {
        const ar0 = a.row(0);
        const ar1 = a.row(1);
        const ar2 = a.row(2);
        const ar3 = a.row(3);
        return .{ @reduce(.Add, ar0 * b), @reduce(.Add, ar1 * b), @reduce(.Add, ar2 * b), @reduce(.Add, ar3 * b) };
    }

    pub fn rotation2(rot: f32) Mat4 {
        const c = common.cos(rot);
        const s = common.sin(rot);
        return .{
            .c0 = .{ c, s, 0, 0 },
            .c1 = .{ -s, c, 0, 0 },
            .c2 = .{ 0, 0, 1, 0 },
            .c3 = .{ 0, 0, 0, 1 },
        };
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

    pub fn scale(val: @Vector(4, f32)) Mat4 {
        return .{
            .c0 = .{ val[0], 0, 0, 0 },
            .c1 = .{ 0, val[1], 0, 0 },
            .c2 = .{ 0, 0, val[2], 0 },
            .c3 = .{ 0, 0, 0, val[3] },
        };
    }

    pub fn translation(amount: @Vector(3, f32)) Mat4 {
        return .{
            .c0 = .{ 1, 0, 0, 0 },
            .c1 = .{ 0, 1, 0, 0 },
            .c2 = .{ 0, 0, 1, 0 },
            .c3 = .{ amount[0], amount[1], amount[2], 1 },
        };
    }
};

export fn main() callconv(.spirv_kernel) void {
    // std.gpu.executionMode(main, .{ .local_size = .{ .x = 64, .y = 1, .z = 1 } }); // Set in build system by `spriv_execution_mode`.

    const sprite_ind = std.gpu.global_invocation_id[0];
    const sprite = sprites.read(sprite_ind);

    const model = Mat4.translation(.{
        sprite.position_rot[0],
        sprite.position_rot[1],
        sprite.position_rot[2],
    }).mul(Mat4.rotation2(sprite.position_rot[3])).mul(Mat4.scale(.{ sprite.scale[0], sprite.scale[1], 1, 1 }));
    const top_left = @Vector(4, f32){ 0, 0, 0, 1 };
    const top_right = @Vector(4, f32){ 1, 0, 0, 1 };
    const bottom_left = @Vector(4, f32){ 0, 1, 0, 1 };
    const bottom_right = @Vector(4, f32){ 1, 1, 0, 1 };
    vertices.write(sprite_ind * 4, .{
        .position = model.mulVec(top_left),
        .tex_coord = .{ sprite.texture[0], sprite.texture[1] },
        .color = sprite.color,
    });
    vertices.write(sprite_ind * 4 + 1, .{
        .position = model.mulVec(top_right),
        .tex_coord = .{ sprite.texture[0] + sprite.texture[2], sprite.texture[1] },
        .color = sprite.color,
    });
    vertices.write(sprite_ind * 4 + 2, .{
        .position = model.mulVec(bottom_left),
        .tex_coord = .{ sprite.texture[0], sprite.texture[1] + sprite.texture[3] },
        .color = sprite.color,
    });
    vertices.write(sprite_ind * 4 + 3, .{
        .position = model.mulVec(bottom_right),
        .tex_coord = .{ sprite.texture[0] + sprite.texture[2], sprite.texture[1] + sprite.texture[3] },
        .color = sprite.color,
    });
}
