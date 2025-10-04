const std = @import("std");

/// Store to a 2d RGBA8 texture.
///
/// ## Function Parameters
/// * `set`: The descriptor set.
/// * `bind`: The binding slot.
/// * `uv`: The UV to store to.
/// * `pixel`: The pixel data to store.
fn store2dRgba8(
    comptime set: u32,
    comptime bind: u32,
    uv: @Vector(2, u32),
    pixel: @Vector(4, f32),
) void {
    asm volatile (
        \\%float          = OpTypeFloat 32
        \\%v4float        = OpTypeVector %float 4
        \\%img_type       = OpTypeImage %float 2D 0 0 0 2 Rgba8
        \\%img_ptr        = OpTypePointer UniformConstant %img_type
        \\%img            = OpVariable %img_ptr UniformConstant
        \\                  OpDecorate %img DescriptorSet $set
        \\                  OpDecorate %img Binding $bind
        \\%loaded_image   = OpLoad %img_type %img
        \\                  OpImageWrite %loaded_image %uv %pixel
        :
        : [uv] "" (uv),
          [pixel] "" (pixel),
          [set] "c" (set),
          [bind] "c" (bind),
    );
}

export fn main() callconv(.spirv_kernel) void {
    // std.gpu.executionMode(main, .{ .local_size = .{ .x = 8, .y = 8, .z = 1 } }); // Set in build system by `spriv_execution_mode`.

    store2dRgba8(1, 0, .{ std.gpu.global_invocation_id[0], std.gpu.global_invocation_id[1] }, .{ 1, 1, 0, 1 });
}
