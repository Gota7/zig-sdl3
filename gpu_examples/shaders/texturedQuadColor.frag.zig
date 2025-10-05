const std = @import("std");

extern var tex_coord_in: @Vector(2, f32) addrspace(.input);
extern var color_in: @Vector(4, f32) addrspace(.input);

extern var color_out: @Vector(4, f32) addrspace(.output);

/// Sample a 2d sampler at a given UV.
///
/// ## Function Parameters
/// * `set`: The descriptor set.
/// * `bind`: The binding slot.
/// * `uv`: The UV to sample at.
///
/// ## Return Value
/// Returns the sampled color value.
fn sampler2d(
    comptime set: u32,
    comptime bind: u32,
    uv: @Vector(2, f32),
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
        \\%ret            = OpImageSampleImplicitLod %v4float %loaded_sampler %uv
        : [ret] "" (-> @Vector(4, f32)),
        : [uv] "" (uv),
          [set] "c" (set),
          [bind] "c" (bind),
    );
}

export fn main() callconv(.spirv_fragment) void {
    std.gpu.location(&tex_coord_in, 0);
    std.gpu.location(&color_in, 1);

    std.gpu.location(&color_out, 0);

    color_out = sampler2d(2, 0, tex_coord_in) * color_in;
}
