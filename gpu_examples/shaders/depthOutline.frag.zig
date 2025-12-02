const common = @import("common.zig");
const std = @import("std");

const color_tex = common.Sampler2d(2, 0);
const depth_tex = common.Sampler2d(2, 1);

extern var tex_coord_in: @Vector(2, f32) addrspace(.input);

extern var color_out: @Vector(4, f32) addrspace(.output);

inline fn getDifference(depth: f32, tex_coord: @Vector(2, f32), distance: f32) f32 {
    const dimi = depth_tex.size(0);
    const dim: @Vector(2, f32) = .{ @floatFromInt(dimi[0]), @floatFromInt(dimi[1]) };
    return @max(
        depth_tex.texture(tex_coord + @Vector(2, f32){ 1.0 / dim[0], 0 } * @as(@Vector(2, f32), @splat(distance)))[0] - depth,
        depth_tex.texture(tex_coord + @Vector(2, f32){ -1.0 / dim[0], 0 } * @as(@Vector(2, f32), @splat(distance)))[0] - depth,
        depth_tex.texture(tex_coord + @Vector(2, f32){ 0, 1.0 / dim[1] } * @as(@Vector(2, f32), @splat(distance)))[0] - depth,
        depth_tex.texture(tex_coord + @Vector(2, f32){ 0, -1.0 / dim[1] } * @as(@Vector(2, f32), @splat(distance)))[0] - depth,
    );
}

fn lerpVec(a: @Vector(3, f32), b: @Vector(3, f32), t: f32) @Vector(3, f32) {
    const t_vec: @Vector(3, f32) = @splat(t);
    return a * (@as(@Vector(3, f32), @splat(1)) - t_vec) + b * t_vec;
}

export fn main() callconv(.spirv_fragment) void {
    std.gpu.location(&tex_coord_in, 0);

    std.gpu.location(&color_out, 0);

    // Get color and depth.
    const color = color_tex.texture(tex_coord_in);
    const depth = depth_tex.texture(tex_coord_in)[0];

    // Get the difference between the edges at 1 and 2 pixels away.
    const edge1: f32 = if (getDifference(depth, tex_coord_in, 1) < 0.2) 0 else 1;
    const edge2: f32 = if (getDifference(depth, tex_coord_in, 2) < 0.2) 0 else 1;

    // Turn inner edges black.
    var res = lerpVec(.{ color[0], color[1], color[2] }, @splat(0), edge2);

    // Turn outer edges white.
    res = lerpVec(res, @splat(1), edge1);

    // Combine results.
    color_out = .{ res[0], res[1], res[2], color[3] };
}
