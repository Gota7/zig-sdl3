const std = @import("std");

const tex_set = 2;
const color_tex = 0;
const depth_tex = 1;

extern var tex_coord_in: @Vector(2, f32) addrspace(.input);

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

inline fn getDifference(depth: f32, tex_coord: @Vector(2, f32), distance: f32) f32 {
    const dimi = samplerSize2d(tex_set, depth_tex, 0);
    const dim: @Vector(2, f32) = .{ @floatFromInt(dimi[0]), @floatFromInt(dimi[1]) };
    return @max(
        sampler2d(tex_set, depth_tex, tex_coord + @Vector(2, f32){ 1.0 / dim[0], 0 } * @as(@Vector(2, f32), @splat(distance)))[0] - depth,
        sampler2d(tex_set, depth_tex, tex_coord + @Vector(2, f32){ -1.0 / dim[0], 0 } * @as(@Vector(2, f32), @splat(distance)))[0] - depth,
        sampler2d(tex_set, depth_tex, tex_coord + @Vector(2, f32){ 0, 1.0 / dim[1] } * @as(@Vector(2, f32), @splat(distance)))[0] - depth,
        sampler2d(tex_set, depth_tex, tex_coord + @Vector(2, f32){ 0, -1.0 / dim[1] } * @as(@Vector(2, f32), @splat(distance)))[0] - depth,
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
    const color = sampler2d(tex_set, color_tex, tex_coord_in);
    const depth = sampler2d(tex_set, depth_tex, tex_coord_in)[0];

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
