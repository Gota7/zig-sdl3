const std = @import("std");

extern var uniforms: extern struct {
    texcoord_multiplier: f32,
} addrspace(.uniform);

const sampler_set = 0;
const sampler_bind = 0;

const img_set = 1;
const img_bind = 0;

/// Sample a 2d sampler at a given UV.
///
/// ## Function Parameters
/// * `set`: The descriptor set.
/// * `bind`: The binding slot.
/// * `uv`: The UV to sample at.
/// * `lod`: The LOD to sample with.
///
/// ## Return Value
/// Returns the sampled color value.
fn sampler2dLod(
    comptime set: u32,
    comptime bind: u32,
    uv: @Vector(2, f32),
    lod: f32,
) @Vector(4, f32) {
    return asm volatile (
        \\%float          = OpTypeFloat 32
        \\%v4float        = OpTypeVector %float 4
        \\%img_type       = OpTypeImage %float 2D 0 0 0 1 Unknown
        \\%sampler_type   = OpTypeSampledImage %img_type
        \\%sampler_ptr    = OpTypePointer UniformConstant %sampler_type
        \\%tex            = OpVariable %sampler_ptr UniformConstant
        \\                  OpDecorate %tex DescriptorSet $set
        \\                  OpDecorate %tex Binding $bind
        \\%loaded_sampler = OpLoad %sampler_type %tex
        \\%ret            = OpImageSampleExplicitLod %v4float %loaded_sampler %uv Lod %lod
        : [ret] "" (-> @Vector(4, f32)),
        : [uv] "" (uv),
          [lod] "" (lod),
          [set] "c" (set),
          [bind] "c" (bind),
    );
}

/// Get the texture size of a 2d sampler.
///
/// ## Function Parameters
/// * `set`: The descriptor set.
/// * `bind`: The binding slot.
/// * `lod`: The LOD to sample at.
///
/// ## Return Value
/// Returns the sampler texture size.
fn samplerSize2d(
    comptime set: u32,
    comptime bind: u32,
    lod: i32,
) @Vector(2, i32) {
    return asm volatile (
        \\                  OpCapability ImageQuery
        \\%float          = OpTypeFloat 32
        \\%int            = OpTypeInt 32 1
        \\%v2int          = OpTypeVector %int 2
        \\%img_type       = OpTypeImage %float 2D 0 0 0 1 Unknown
        \\%sampler_type   = OpTypeSampledImage %img_type
        \\%sampler_ptr    = OpTypePointer UniformConstant %sampler_type
        \\%tex            = OpVariable %sampler_ptr UniformConstant
        \\                  OpDecorate %tex DescriptorSet $set
        \\                  OpDecorate %tex Binding $bind
        \\%loaded_sampler = OpLoad %sampler_type %tex
        \\%loaded_image   = OpImage %img_type %loaded_sampler
        \\%ret            = OpImageQuerySizeLod %v2int %loaded_image %lod
        : [ret] "" (-> @Vector(2, i32)),
        : [set] "c" (set),
          [bind] "c" (bind),
          [lod] "" (lod),
    );
}

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

    std.gpu.binding(&uniforms, 2, 0);

    const image_sizei = samplerSize2d(sampler_set, sampler_bind, 0);
    const image_size = @Vector(2, f32){ @floatFromInt(image_sizei[0]), @floatFromInt(image_sizei[1]) };
    const uvi = @Vector(2, u32){ std.gpu.global_invocation_id[0], std.gpu.global_invocation_id[1] };
    const uv = @Vector(2, f32){
        @as(f32, @floatFromInt(uvi[0])) * uniforms.texcoord_multiplier / image_size[0],
        @as(f32, @floatFromInt(uvi[1])) * uniforms.texcoord_multiplier / image_size[1],
    };
    store2dRgba8(img_set, img_bind, uvi, sampler2dLod(sampler_set, sampler_bind, uv, 0));
}
