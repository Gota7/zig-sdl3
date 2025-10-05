const std = @import("std");

extern var uniforms: extern struct {
    time: f32,
} addrspace(.uniform);

const img_set = 1;
const img_bind = 0;

const cos_inst = 14; // https://registry.khronos.org/SPIR-V/specs/unified1/GLSL.std.450.html

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

/// Get the texture size of a 2d RGBA8 texture.
///
/// ## Function Parameters
/// * `set`: The descriptor set.
/// * `bind`: The binding slot.
/// * `lod`: The LOD to sample at.
///
/// ## Return Value
/// Returns the texture size.
fn size2dRgba8(
    comptime set: u32,
    comptime bind: u32,
) @Vector(2, i32) {
    return asm volatile (
        \\                  OpCapability ImageQuery
        \\%float          = OpTypeFloat 32
        \\%int            = OpTypeInt 32 1
        \\%v2int          = OpTypeVector %int 2
        \\%img_type       = OpTypeImage %float 2D 0 0 0 2 Rgba8
        \\%img_ptr        = OpTypePointer UniformConstant %img_type
        \\%img            = OpVariable %img_ptr UniformConstant
        \\                  OpDecorate %img DescriptorSet $set
        \\                  OpDecorate %img Binding $bind
        \\%loaded_image   = OpLoad %img_type %img
        \\%ret            = OpImageQuerySize %v2int %loaded_image
        : [ret] "" (-> @Vector(2, i32)),
        : [set] "c" (set),
          [bind] "c" (bind),
    );
}

/// SPIR-V on zig currently can not use cosine, use some inline assembly to steal from GLSL's extended instruction set.
///
/// ## Function Parameters
/// * `vec`: The vector to get the cosine of.
///
/// ## Return Value
/// Returns a vector where all the elements are the cosines of the inputs.
fn cosVec3(
    vec: @Vector(3, f32),
) @Vector(3, f32) {
    return asm volatile (
        \\%glsl_ext       = OpExtInstImport "GLSL.std.450"
        \\%float          = OpTypeFloat 32
        \\%v3float        = OpTypeVector %float 3
        \\%ret            = OpExtInst %v3float %glsl_ext $cos_inst %vec
        : [ret] "" (-> @Vector(3, f32)),
        : [vec] "" (vec),
          [cos_inst] "c" (cos_inst),
    );
}

export fn main() callconv(.spirv_kernel) void {
    // std.gpu.executionMode(main, .{ .local_size = .{ .x = 8, .y = 8, .z = 1 } }); // Set in build system by `spriv_execution_mode`.

    std.gpu.binding(&uniforms, 2, 0);

    const image_sizei = size2dRgba8(img_set, img_bind);
    const image_size = @Vector(2, f32){ @floatFromInt(image_sizei[0]), @floatFromInt(image_sizei[1]) };
    const uvi = @Vector(2, u32){ std.gpu.global_invocation_id[0], std.gpu.global_invocation_id[1] };
    const uv = @Vector(2, f32){
        @as(f32, @floatFromInt(uvi[0])) / image_size[0],
        @as(f32, @floatFromInt(uvi[1])) / image_size[1],
    };

    const half_vec = @as(@Vector(3, f32), @splat(0.5));
    const color = half_vec + (cosVec3((@as(@Vector(3, f32), @splat(uniforms.time)) + @Vector(3, f32){ uv[0], uv[1], uv[0] }) + @Vector(3, f32){ 0, 2, 4 }) * half_vec);
    store2dRgba8(img_set, img_bind, uvi, .{ color[0], color[1], color[2], 1 });
}
