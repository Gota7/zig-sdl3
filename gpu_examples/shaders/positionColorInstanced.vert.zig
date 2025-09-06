const std = @import("std");

extern var position_in: @Vector(3, f32) addrspace(.input);
extern var color_in: @Vector(4, f32) addrspace(.input);

extern var color_out: @Vector(4, f32) addrspace(.output);

export fn main() callconv(.spirv_vertex) void {
    std.gpu.location(&position_in, 0);
    std.gpu.location(&color_in, 1);

    std.gpu.location(&color_out, 0);

    color_out = color_in;
    const instance_index = std.gpu.instance_index;
    var pos = position_in * @as(@Vector(3, f32), @splat(0.25)) - @Vector(3, f32){ 0.75, 0.75, 0.0 };
    pos[0] += @as(f32, @floatFromInt(instance_index % 4)) * 0.5;
    pos[1] += @floor(@as(f32, @floatFromInt(instance_index / 4))) * 0.5;
    std.gpu.position_out.* = .{ pos[0], pos[1], pos[2], 1 };
}
