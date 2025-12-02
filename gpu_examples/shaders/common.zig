/// SPIR-V on zig currently can not use cosine, use some inline assembly to steal from GLSL's extended instruction set.
///
/// ## Function Parameters
/// * `val`: The scalar or vector to get the cosine of.
///
/// ## Return Value
/// Returns a scalar or vector with the cosines of each element.
pub fn cos(val: anytype) @TypeOf(val) {
    // https://registry.khronos.org/SPIR-V/specs/unified1/GLSL.std.450.html
    return asm volatile (
        \\%glsl_ext       = OpExtInstImport "GLSL.std.450"
        \\%ret            = OpExtInst %val_type %glsl_ext 14 %val
        : [ret] "" (-> @TypeOf(val)),
        : [val] "" (val),
          [val_type] "t" (@TypeOf(val)),
    );
}

/// SPIR-V on zig currently can not use sine, use some inline assembly to steal from GLSL's extended instruction set.
///
/// ## Function Parameters
/// * `val`: The scalar or vector to get the sine of.
///
/// ## Return Value
/// Returns a scalar or vector with the sines of each element.
pub fn sin(val: anytype) @TypeOf(val) {
    // https://registry.khronos.org/SPIR-V/specs/unified1/GLSL.std.450.html
    return asm volatile (
        \\%glsl_ext       = OpExtInstImport "GLSL.std.450"
        \\%ret            = OpExtInst %val_type %glsl_ext 13 %val
        : [ret] "" (-> @TypeOf(val)),
        : [val] "" (val),
          [val_type] "t" (@TypeOf(val)),
    );
}

/// Create a runtime array for a type.
///
/// ## Function Parameters
/// * `set`: The binding set of the array.
/// * `bind`: The binding slot of the array.
/// * `Type`: Type of element stored in the array.
///
/// ## Return Value
/// Returns the runtime array.
pub fn RuntimeArray(
    comptime set: u32,
    comptime bind: u32,
    comptime Type: type,
) type {
    return struct {
        /// Read from a runtime array storage buffer.
        ///
        /// ## Function Parameters
        /// * `index`: Index to access the element in the runtime array.
        ///
        /// ## Return Value
        /// Returns the value at the given index in the array.
        pub fn read(
            index: u32,
        ) Type {
            return asm volatile (
                \\%int              = OpTypeInt 32 1
                \\%zero             = OpConstant %int 0
                \\%uniform_ptr_type = OpTypePointer StorageBuffer %entry_type
                \\%arr              = OpTypeRuntimeArray %entry_type
                \\%compute_buffer   = OpTypeStruct %arr
                \\%uniform_type     = OpTypePointer StorageBuffer %compute_buffer
                \\%uniform          = OpVariable %uniform_type StorageBuffer
                \\                    OpDecorate %uniform DescriptorSet $set
                \\                    OpDecorate %uniform Binding $bind
                \\%access           = OpAccessChain %uniform_ptr_type %uniform %zero %index
                \\%ret              = OpLoad %entry_type %access
                : [ret] "" (-> Type),
                : [entry_type] "t" (Type),
                  [index] "" (index),
                  [set] "c" (set),
                  [bind] "c" (bind),
            );
        }

        /// Write to a runtime array storage buffer.
        ///
        /// ## Function Parameters
        /// * `index`: Index to access the element in the runtime array.
        /// * `val`: Value to write to the given index in the runtime array.
        pub fn write(
            index: u32,
            val: Type,
        ) void {
            asm volatile (
                \\%int              = OpTypeInt 32 1
                \\%zero             = OpConstant %int 0
                \\%uniform_ptr_type = OpTypePointer StorageBuffer %entry_type
                \\%arr              = OpTypeRuntimeArray %entry_type
                \\%compute_buffer   = OpTypeStruct %arr
                \\%uniform_type     = OpTypePointer StorageBuffer %compute_buffer
                \\%uniform          = OpVariable %uniform_type StorageBuffer
                \\                    OpDecorate %uniform DescriptorSet $set
                \\                    OpDecorate %uniform Binding $bind
                \\%access           = OpAccessChain %uniform_ptr_type %uniform %zero %index
                \\                    OpStore %access %val
                :
                : [entry_type] "t" (Type),
                  [index] "" (index),
                  [val] "" (val),
                  [set] "c" (set),
                  [bind] "c" (bind),
            );
        }
    };
}

/// Create a 2d sampler.
///
/// ## Function Parameters
/// * `set`: The descriptor set.
/// * `bind`: The binding slot.
///
/// ## Return Value
/// The 2d sampler object.
pub fn Sampler2d(
    comptime set: u32,
    comptime bind: u32,
) type {
    return struct {
        /// Get the texture size of a 2d sampler.
        ///
        /// ## Function Parameters
        /// * `lod`: The LOD to sample at.
        ///
        /// ## Return Value
        /// Returns the sampler texture size.
        pub fn size(
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

        /// Sample the 2d sampler at a given UV.
        ///
        /// ## Function Parameters
        /// * `uv`: The UV to sample at.
        ///
        /// ## Return Value
        /// Returns the sampled color value.
        pub fn texture(
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

        /// Sample a 2d sampler at a given UV.
        ///
        /// ## Function Parameters
        /// * `uv`: The UV to sample at.
        /// * `lod`: The LOD to sample with.
        ///
        /// ## Return Value
        /// Returns the sampled color value.
        pub fn textureLod(
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
    };
}

/// Create a 2d sampler array.
///
/// ## Function Parameters
/// * `set`: The descriptor set.
/// * `bind`: The binding slot.
///
/// ## Return Value
/// The 2d sampler array object.
pub fn Sampler2dArray(
    comptime set: u32,
    comptime bind: u32,
) type {
    return struct {
        /// Sample the 2d sampler array at a given UV.
        ///
        /// ## Function Parameters
        /// * `uv`: The UV to sample at.
        ///
        /// ## Return Value
        /// Returns the sampled color value.
        pub fn texture(
            uv: @Vector(3, f32),
        ) @Vector(4, f32) {
            return asm volatile (
                \\%float          = OpTypeFloat 32
                \\%v4float        = OpTypeVector %float 4
                \\%img_type       = OpTypeImage %float 2D 0 1 0 1 Unknown
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
    };
}

/// Create a cube sampler.
///
/// ## Function Parameters
/// * `set`: The descriptor set.
/// * `bind`: The binding slot.
///
/// ## Return Value
/// The 2d sampler object.
pub fn SamplerCube(
    comptime set: u32,
    comptime bind: u32,
) type {
    return struct {
        /// Sample a cube sampler at a given UV.
        ///
        /// ## Function Parameters
        /// * `uv`: The UV to sample at.
        ///
        /// ## Return Value
        /// Returns the sampled color value.
        pub fn texture(
            uv: @Vector(3, f32),
        ) @Vector(4, f32) {
            return asm volatile (
                \\%float          = OpTypeFloat 32
                \\%v4float        = OpTypeVector %float 4
                \\%img_type       = OpTypeImage %float Cube 0 0 0 1 Unknown
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
    };
}

/// Create a 2d texture in RGBA8 format.
///
/// ## Function Parameters
/// * `set`: The descriptor set.
/// * `bind`: The binding slot.
///
/// ## Return Value
/// The 2d RGBA8 texture object.
pub fn Texture2dRgba8(
    comptime set: u32,
    comptime bind: u32,
) type {
    return struct {
        /// Get the texture size of a 2d RGBA8 texture.
        ///
        /// ## Return Value
        /// Returns the texture size.
        pub fn size() @Vector(2, i32) {
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

        /// Store to a 2d RGBA8 texture.
        ///
        /// ## Function Parameters
        /// * `uv`: The UV to store to.
        /// * `pixel`: The pixel data to store.
        pub fn store(
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
    };
}
