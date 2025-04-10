const C = @import("c.zig").C;
const errors = @import("errors.zig");
const pixels = @import("pixels.zig");
const properties = @import("properties.zig");
const rect = @import("rect.zig");
const std = @import("std");
const surface = @import("surface.zig");

/// Specifies a blending factor to be used when pixels in a render target are blended with existing pixels in the texture.
///
/// ## Remarks
/// The source color is the value written by the fragment shader.
/// The destination color is the value currently existing in the texture.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const BlendFactor = enum(c_uint) {
    /// 0.
    zero = C.SDL_GPU_BLENDFACTOR_ZERO,
    /// 1.
    one = C.SDL_GPU_BLENDFACTOR_ONE,
    /// Source color.
    src_color = C.SDL_GPU_BLENDFACTOR_SRC_COLOR,
    /// 1 - Source color.
    one_minus_src_color = C.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_COLOR,
    /// Destination color.
    dst_color = C.SDL_GPU_BLENDFACTOR_DST_COLOR,
    /// 1 - Destination color.
    one_minus_dst_color = C.SDL_GPU_BLENDFACTOR_ONE_MINUS_DST_COLOR,
    /// Source alpha.
    src_alpha = C.SDL_GPU_BLENDFACTOR_SRC_ALPHA,
    /// 1 - Source alpha.
    one_minus_src_alpha = C.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
    /// Destination alpha.
    dst_alpha = C.SDL_GPU_BLENDFACTOR_DST_ALPHA,
    /// 1 - Destination alpha.
    one_minus_dst_alpha = C.SDL_GPU_BLENDFACTOR_ONE_MINUS_DST_ALPHA,
    /// Blend constant.
    constant_color = C.SDL_GPU_BLENDFACTOR_CONSTANT_COLOR,
    /// 1 - Blend constant.
    one_minus_constant_color = C.SDL_GPU_BLENDFACTOR_ONE_MINUS_CONSTANT_COLOR,
    /// Min(Source alpha, Destination alpha).
    src_alpha_saturate = C.SDL_GPU_BLENDFACTOR_SRC_ALPHA_SATURATE,

    /// Make a blend factor from SDL.
    pub fn fromSdl(val: C.SDL_GPUBlendFactor) ?BlendFactor {
        if (val == C.SDL_GPU_BLENDFACTOR_INVALID) {
            return null;
        }
        return @enumFromInt(val);
    }

    /// Convert a blend factor to an SDL value.
    pub fn toSdl(val: ?BlendFactor) C.SDL_GPUBlendFactor {
        if (val) |tmp| {
            return @intFromEnum(tmp);
        }
        return C.SDL_GPU_BLENDFACTOR_INVALID;
    }
};

/// Specifies the operator to be used when pixels in a render target are blended with existing pixels in the texture.
///
/// ## Remarks
/// The source color is the value written by the fragment shader.
/// The destination color is the value currently existing in the texture.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const BlendOperation = enum(c_uint) {
    /// (Source * Source Factor) + (Destination * Destination Factor).
    add = C.SDL_BLENDOPERATION_ADD,
    /// (Source * Source Factor) - (Destination * Destination Factor).
    subtract = C.SDL_BLENDOPERATION_SUBTRACT,
    /// (Destination * Destination Factor) - (Source * Source Factor).
    reverse_subtract = C.SDL_BLENDOPERATION_REV_SUBTRACT,
    /// Min(Source, Destination).
    min = C.SDL_BLENDOPERATION_MINIMUM,
    /// Max(Source, Destination).
    max = C.SDL_BLENDOPERATION_MAXIMUM,

    /// Create from SDL.
    pub fn fromSdl(val: C.SDL_GPUBlendOp) ?BlendOperation {
        if (val == C.SDL_GPU_BLENDOP_INVALID) {
            return null;
        }
        return @enumFromInt(val);
    }

    /// Convert to an SDL value.
    pub fn toSdl(val: ?BlendOperation) C.SDL_GPUBlendOp {
        if (val) |tmp| {
            return @intFromEnum(tmp);
        }
        return C.SDL_GPU_BLENDOP_INVALID;
    }
};

/// A structure containing parameters for a blit command.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const BlitInfo = struct {
    /// The source region for the blit.
    source: BlitRegion,
    /// The destination region for the blit.
    destination: BlitRegion,
    /// What is done with the contents of the destination before the blit.
    load_op: LoadOperation,
    /// The color to clear the destination region to before the blit.
    /// Ignored if `load_op` is not `gpu.LoadOperation.clear`.
    clear_color: pixels.FColor,
    /// The flip mode for the source region.
    flip_mode: ?surface.FlipMode,
    /// The filter mode used when blitting.
    filter: Filter,
    /// True cycles the destination texture if it is already bound.
    cycle: bool,

    /// Convert from SDL.
    pub fn fromSdl(value: C.SDL_GPUBlitInfo) BlitInfo {
        return .{
            .source = BlitRegion.fromSdl(value.source),
            .destination = BlitRegion.fromSdl(value.destination),
            .load_op = @enumFromInt(value.load_op),
            .clear_color = value.clear_color,
            .flip_mode = surface.FlipMode.fromSdl(value.flip_mode),
            .filter = @enumFromInt(value.filter),
            .cycle = value.cycle,
        };
    }

    /// Convert to SDL.
    pub fn toSdl(self: BlitInfo) C.SDL_GPUBlitInfo {
        return .{
            .source = self.source.toSdl(),
            .destination = self.destination.toSdl(),
            .load_op = @intFromEnum(self.load_op),
            .clear_color = self.clear_color,
            .flip_mode = surface.FlipMode.toSdl(self.flip_mode),
            .filter = @intFromEnum(self.filter),
            .cycle = self.cycle,
        };
    }
};

/// A structure specifying a region of a texture used in the blit operation.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const BlitRegion = struct {
    /// The texture.
    texture: Texture,
    /// The mip level index of the region.
    mip_level: u32,
    /// The layer index or depth plane of the region.
    /// This value is treated as a layer index on 2D array and cube textures, and as a depth plane on 3D textures.
    layer_or_depth_plane: u32,
    /// The region.
    region: rect.Rect(u32),

    /// Convert from an SDL value.
    pub fn fromSdl(value: C.SDL_GPUBlitRegion) BlitRegion {
        return .{
            .texture = .{ .value = value.texture.? },
            .mip_level = value.mip_level,
            .layer_or_depth_plane = value.layer_or_depth_plane,
            .region = .{
                .x = value.x,
                .y = value.y,
                .w = value.w,
                .h = value.h,
            },
        };
    }

    /// Convert to an SDL value.
    pub fn toSdl(self: BlitRegion) C.SDL_GPUBlitRegion {
        return .{
            .texture = self.texture.value,
            .mip_level = self.mip_level,
            .layer_or_depth_plane = self.layer_or_depth_plane,
            .x = self.region.x,
            .y = self.region.y,
            .w = self.region.w,
            .h = self.region.h,
        };
    }
};

/// An opaque handle representing a buffer.
///
/// ## Remarks
/// Used for vertices, indices, indirect draw commands, and general compute data.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const Buffer = packed struct {
    value: *C.SDL_GPUBuffer,
};

/// A structure specifying parameters in a buffer binding call.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const BufferBinding = extern struct {
    /// The buffer to bind. Must have been created with `gpu.BufferUsageFlags.vertex` for `gpu.RenderPass.bindVertexBuffers()`,
    /// or `gpu.BufferUsageFlags.index` for S`gpu.RenderPass.bindIndexBuffers()`.
    buffer: Buffer,
    /// The starting byte of the data to bind in the buffer.
    offset: u32,
};

/// A structure specifying the parameters of a buffer.
///
/// ## Remarks
/// Note that certain combinations of usage flags are invalid, for example `gpu.BufferUsageFlags.vertex` and `gpu.BufferUsageFlags.index`.
pub const BufferCreateInfo = struct {
    /// How the buffer is intended to be used by the client.
    usage: BufferUsageFlags,
    /// The size in bytes of the buffer.
    size: u32,
    /// Properties for extensions.
    props: ?properties.Group,

    /// Convert from an SDL value.
    pub fn fromSdl(value: C.SDL_GPUBufferCreateInfo) BufferCreateInfo {
        return .{
            .usage = BufferUsageFlags.fromSdl(value.usage),
            .size = value.size,
            .props = if (value.props == 0) null else .{ .value = value.props },
        };
    }

    /// Convert to an SDL value.
    pub fn toSdl(self: BufferCreateInfo) C.SDL_GPUBufferCreateInfo {
        return .{
            .usage = self.usage.toSdl(),
            .size = self.size,
            .props = if (self.props) |val| val.value else 0,
        };
    }
};

/// A structure specifying a location in a buffer.
///
/// ## Remarks
/// Used when copying data between buffers.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const BufferLocation = struct {
    /// The buffer.
    buffer: Buffer,
    /// The starting byte within the buffer.
    offset: u32,

    /// Convert from an SDL value.
    pub fn fromSdl(value: C.SDL_GPUBufferLocation) BufferLocation {
        return .{
            .buffer = .{ .value = value.buffer.? },
            .offset = value.offset,
        };
    }

    /// Convert to an SDL value.
    pub fn toSdl(self: BufferLocation) C.SDL_GPUBufferLocation {
        return .{
            .buffer = self.buffer.value,
            .offset = self.offset,
        };
    }
};

/// A structure specifying a region of a buffer.
///
/// ## Remarks
/// Used when transferring data to or from buffers.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const BufferRegion = struct {
    /// The buffer.
    buffer: Buffer,
    /// The starting byte within the buffer.
    offset: u32,
    /// The size in bytes of the region.
    size: u32,

    /// Convert from an SDL value.
    pub fn fromSdl(value: C.SDL_GPUBufferRegion) BufferRegion {
        return .{
            .buffer = .{ .value = value.buffer.? },
            .offset = value.offset,
            .size = value.size,
        };
    }

    /// Convert to an SDL value.
    pub fn toSdl(self: BufferRegion) C.SDL_GPUBufferRegion {
        return .{
            .buffer = self.buffer.value,
            .offset = self.offset,
            .size = self.size,
        };
    }
};

/// Specifies how a buffer is intended to be used by the client.
///
/// ## Remarks
/// A buffer must have at least one usage flag.
/// Note that some usage flag combinations are invalid.
///
/// Unlike textures, specifying both a "read" and "write" can be used for simultaneous read-write usage.
/// The same data synchronization concerns as textures apply.
///
/// If you use a "storage" flag, the data in the buffer must respect std140 layout conventions.
/// In practical terms this means you must ensure that vec3 and vec4 fields are 16-byte aligned.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const BufferUsageFlags = struct {
    /// Buffer is a vertex buffer.
    vertex: bool = false,
    /// Buffer is an index buffer.
    index: bool = false,
    /// Buffer is an indirect buffer.
    indirect: bool = false,
    /// Buffer supports storage reads in graphics stages.
    graphics_storage_read: bool = false,
    /// Buffer supports storage reads in the compute stage.
    compute_storage_read: bool = false,
    /// Buffer supports storage writes in the compute stage.
    compute_storage_write: bool = false,

    /// Convert flags from SDL.
    pub fn fromSdl(val: C.SDL_GPUBufferUsageFlags) BufferUsageFlags {
        return .{
            .vertex = val & C.SDL_GPU_BUFFERUSAGE_VERTEX,
            .index = val & C.SDL_GPU_BUFFERUSAGE_INDEX,
            .indirect = val & C.SDL_GPU_BUFFERUSAGE_INDIRECT,
            .graphics_storage_read = val & C.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
            .compute_storage_read = val & C.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_READ,
            .compute_storage_write = val & C.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE,
        };
    }

    /// Get the SDL flags.
    pub fn toSdl(self: BufferUsageFlags) C.SDL_GPUBufferUsageFlags {
        const ret: C.SDL_GPUBufferUsageFlags = 0;
        if (self.vertex)
            ret |= C.SDL_GPU_BUFFERUSAGE_VERTEX;
        if (self.index)
            ret |= C.SDL_GPU_BUFFERUSAGE_INDEX;
        if (self.indirect)
            ret |= C.SDL_GPU_BUFFERUSAGE_INDIRECT;
        if (self.graphics_storage_read)
            ret |= C.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ;
        if (self.compute_storage_read)
            ret |= C.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_READ;
        if (self.compute_storage_write)
            ret |= C.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE;
        return ret;
    }
};

/// Specifies which color components are written in a graphics pipeline.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const ColorComponentFlags = packed struct(C.SDL_GPUColorComponentFlags) {
    red: bool = false,
    green: bool = false,
    blue: bool = false,
    alpha: bool = false,
    _: u4 = 0,
};

/// A structure specifying the blend state of a color target.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const ColorTargetBlendState = extern struct {
    /// The value to be multiplied by the source RGB value.
    source_color: BlendFactor,
    /// The value to be multiplied by the destination RGB value.
    destination_color: BlendFactor,
    /// The blend operation for the RGB components.
    color_blend: BlendOperation,
    /// The value to be multiplied by the source alpha.
    source_alpha: BlendFactor,
    /// The value to be multiplied by the destination alpha.
    destination_alpha: BlendFactor,
    /// The blend operation for the alpha component.
    alpha_blend: BlendOperation,
    /// A bitmask specifying which of the RGBA components are enabled for writing.
    /// Writes to all channels if `enable_color_write_mask` is false.
    color_write_mask: ColorComponentFlags,
    /// Whether blending is enabled for the color target.
    enable_blend: bool,
    /// Whether the color write mask is enabled.
    enable_color_write_mask: bool,
    _1: u8 = 0,
    _2: u8 = 0,
};

/// A structure specifying the parameters of color targets used in a graphics pipeline.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const ColorTargetDescription = extern struct {
    /// The pixel format of the texture to be used as a color target.
    format: TextureFormat,
    /// The blend state to be used for the color target.
    blend_state: ColorTargetBlendState,
};

/// A structure specifying the parameters of a color target used by a render pass.
///
/// ## Remarks
/// The load_op field determines what is done with the texture at the beginning of the render pass.
///
/// LOAD: Loads the data currently in the texture. Not recommended for multisample textures as it requires significant memory bandwidth.
/// CLEAR: Clears the texture to a single color.
/// DONT_CARE: The driver will do whatever it wants with the texture memory. This is a good option if you know that every single pixel will be touched in the render pass.
/// The store_op field determines what is done with the color results of the render pass.
///
/// STORE: Stores the results of the render pass in the texture. Not recommended for multisample textures as it requires significant memory bandwidth.
/// DONT_CARE: The driver will do whatever it wants with the texture memory. This is often a good option for depth/stencil textures.
/// RESOLVE: Resolves a multisample texture into resolve_texture, which must have a sample count of 1. Then the driver may discard the multisample texture memory. This is the most performant method of resolving a multisample target.
/// RESOLVE_AND_STORE: Resolves a multisample texture into the resolve_texture, which must have a sample count of 1. Then the driver stores the multisample texture's contents. Not recommended as it requires significant memory bandwidth.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const ColorTargetInfo = extern struct {
    texture: Texture,
    mip_level: u32,
    layer_or_depth_plane: u32,
    clear_color: pixels.FColor, // TODO: FIX DOCS ABOVE, GIVE THESE COMMENTS, WRITE TESTS!!!
    load: LoadOperation,
    store: StoreOperation,
    resolve_texture: Texture,
    resolve_mip_level: u32,
    resolve_layer: u32,
    cycle: bool,
    cycle_resolve_texture: bool,
    _1: u8 = 0,
    _2: u8 = 0,
};

/// An opaque handle representing a command buffer.
///
/// ## Remarks
/// Most state is managed via command buffers.
/// When setting state using a command buffer, that state is local to the command buffer.
///
/// Commands only begin execution on the GPU once `gpu.CommandBuffer.submit()` is called.
/// Once the command buffer is submitted, it is no longer valid to use it.
///
/// Command buffers are executed in submission order.
/// If you submit command buffer A and then command buffer B all commands in A will begin executing before any command in B begins executing.
///
/// In multi-threading scenarios, you should only access a command buffer on the thread you acquired it from.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const CommandBuffer = packed struct {
    value: *C.SDL_GPUCommandBuffer,
};

/// Specifies a comparison operator for depth, stencil and sampler operations.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const CompareOperation = enum(c_uint) {
    /// The comparison always evaluates false.
    never = C.SDL_GPU_COMPAREOP_NEVER,
    /// The comparison evaluates reference < test.
    less = C.SDL_GPU_COMPAREOP_LESS,
    /// The comparison evaluates reference == test.
    equal = C.SDL_GPU_COMPAREOP_EQUAL,
    /// The comparison evaluates reference <= test.
    less_or_equal = C.SDL_GPU_COMPAREOP_LESS_OR_EQUAL,
    /// The comparison evaluates reference > test.
    greater = C.SDL_GPU_COMPAREOP_GREATER,
    /// The comparison evaluates reference != test.
    not_equal = C.SDL_GPU_COMPAREOP_NOT_EQUAL,
    /// The comparison evaluates reference >= test.
    greater_or_equal = C.SDL_GPU_COMPAREOP_GREATER_OR_EQUAL,
    /// The comparison always evaluates true.
    always = C.SDL_GPU_COMPAREOP_ALWAYS,

    /// Create from SDL.
    pub fn fromSdl(val: C.SDL_GPUCompareOp) ?CompareOperation {
        if (val == C.SDL_GPU_COMPAREOP_INVALID) {
            return null;
        }
        return @enumFromInt(val);
    }

    /// Convert to an SDL value.
    pub fn toSdl(val: ?CompareOperation) C.SDL_GPUCompareOp {
        if (val) |tmp| {
            return @intFromEnum(tmp);
        }
        return C.SDL_GPU_COMPAREOP_INVALID;
    }
};

/// An opaque handle representing a compute pass.
///
/// ## Remarks
/// This handle is transient and should not be held or referenced after `gpu.ComputePass.end()` is called.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const ComputePass = packed struct {
    value: *C.SDL_GPUComputePass,
};

/// An opaque handle representing a compute pipeline.
///
/// ## Remarks
/// Used during compute passes.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const ComputePipeline = packed struct {
    value: *C.SDL_GPUComputePipeline,
};

/// An opaque handle representing a copy pass.
///
/// ## Remarks
/// This handle is transient and should not be held or referenced after `gpu.CopyPass.end()` is called.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const CopyPass = packed struct {
    value: *C.SDL_GPUCopyPass,
};

/// Specifies the face of a cube map.
///
/// ## Remarks
/// Can be passed in as the layer field in texture-related structs.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const CubeMap = enum(c_uint) {
    positive_x = C.SDL_GPU_CUBEMAPFACE_POSITIVEX,
    negative_x = C.SDL_GPU_CUBEMAPFACE_NEGATIVEX,
    positive_y = C.SDL_GPU_CUBEMAPFACE_POSITIVEY,
    negative_y = C.SDL_GPU_CUBEMAPFACE_NEGATIVEY,
    positive_z = C.SDL_GPU_CUBEMAPFACE_POSITIVEZ,
    negative_z = C.SDL_GPU_CUBEMAPFACE_NEGATIVEZ,
};

/// Specifies the facing direction in which triangle faces will be culled.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const CullMode = enum(c_uint) {
    /// No triangles are culled.
    none = C.SDL_GPU_CULLMODE_NONE,
    /// Front-facing triangles are culled.
    front = C.SDL_GPU_CULLMODE_FRONT,
    /// Back-facing triangles are culled.
    back = C.SDL_GPU_CULLMODE_BACK,
};

/// An opaque handle representing the SDL_GPU context.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const Device = packed struct {
    value: *C.SDL_GPUDevice,
};

/// An opaque handle representing a fence.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const Fence = packed struct {
    value: *C.SDL_GPUFence,
};

/// Specifies the fill mode of the graphics pipeline.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const FillMode = enum(c_uint) {
    /// Polygons will be rendered via rasterization.
    fill = C.SDL_GPU_FILLMODE_FILL,
    /// Polygon edges will be drawn as line segments.
    line = C.SDL_GPU_FILLMODE_LINE,
};

/// Specifies a filter operation used by a sampler.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const Filter = enum(c_uint) {
    /// Point filtering.
    nearest = C.SDL_GPU_FILTER_NEAREST,
    /// Linear filtering.
    linear = C.SDL_GPU_FILTER_LINEAR,
};

/// Specifies the vertex winding that will cause a triangle to be determined to be front-facing.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const FrontFace = enum(c_uint) {
    /// A triangle with counter-clockwise vertex winding will be considered front-facing.
    counter_clockwise = C.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,
    /// A triangle with clockwise vertex winding will be considered front-facing.
    clockwise = C.SDL_GPU_FRONTFACE_CLOCKWISE,
};

/// An opaque handle representing a graphics pipeline.
///
/// ## Remarks
/// Used during render passes.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const GraphicsPipeline = packed struct {
    value: *C.SDL_GPUGraphicsPipeline,
};

/// Specifies the size of elements in an index buffer.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const IndexElementSize = enum(c_uint) {
    /// The index elements are 16-bit.
    indices_16bit = C.SDL_GPU_INDEXELEMENTSIZE_16BIT,
    /// The index elements are 32-bit.
    indices_32bit = C.SDL_GPU_INDEXELEMENTSIZE_32BIT,
};

/// Specifies how the contents of a texture attached to a render pass are treated at the beginning of the render pass.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const LoadOperation = enum(c_uint) {
    /// The previous contents of the texture will be preserved.
    load = C.SDL_GPU_LOADOP_LOAD,
    /// The contents of the texture will be cleared to a color.
    clear = C.SDL_GPU_LOADOP_CLEAR,
    /// The previous contents of the texture need not be preserved.
    /// The contents will be undefined.
    do_not_care = C.SDL_GPU_LOADOP_DONT_CARE,
};

/// Specifies the timing that will be used to present swapchain textures to the OS.
///
/// ## Remarks
/// `gpu.PresentMode.vsync` mode will always be supported.
/// `gpu.PresentMode.immediate` and `gpu.PresentMode.mailbox` modes may not be supported on certain systems.
///
/// It is recommended to query `video.Window.supportsGpuPresentMode()` after claiming the window
/// if you wish to change the present mode to `gpu.PresentMode.immediate` or `gpu.PresentMode.mailbox`.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const PresentMode = enum(c_uint) {
    /// Waits for vblank before presenting.
    /// No tearing is possible.
    /// If there is a pending image to present, the new image is enqueued for presentation.
    /// Disallows tearing at the cost of visual latency.
    vsync = C.SDL_GPU_PRESENTMODE_VSYNC,
    /// Immediately presents.
    /// Lowest latency option, but tearing may occur.
    immediate = C.SDL_GPU_PRESENTMODE_IMMEDIATE,
    /// Waits for vblank before presenting.
    /// No tearing is possible.
    /// If there is a pending image to present, the pending image is replaced by the new image.
    /// Similar to `gpu.PresentMode.vsync`, but with reduced visual latency.
    mailbox = C.SDL_GPU_PRESENTMODE_MAILBOX,
};

/// Specifies the primitive topology of a graphics pipeline.
///
/// ## Remarks
/// If you are using `gpu.PrimitiveType.point_list` you must include a point size output in the vertex shader:
/// * For HLSL compiling to SPIRV you must decorate a float output with `[[vk::builtin("PointSize")]]`.
/// * For GLSL you must set the `gl_PointSize` builtin.
/// * For MSL you must include a float output with the `[[point_size]]` decorator.
///
/// Note that sized point topology is totally unsupported on D3D12.
/// Any size other than 1 will be ignored.
/// In general, you should avoid using point topology for both compatibility and performance reasons.
/// You WILL regret using it.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const PrimitiveType = enum(c_uint) {
    /// A series of separate triangles.
    triangle_list = C.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
    /// A series of connected triangles.
    triangle_strip = C.SDL_GPU_PRIMITIVETYPE_TRIANGLESTRIP,
    /// A series of separate lines.
    line_list = C.SDL_GPU_PRIMITIVETYPE_LINELIST,
    /// A series of connected lines.
    line_strip = C.SDL_GPU_PRIMITIVETYPE_LINESTRIP,
    /// A series of separate points.
    point_list = C.SDL_GPU_PRIMITIVETYPE_POINTLIST,
};

/// An opaque handle representing a render pass.
///
/// ## Remarks
/// This handle is transient and should not be held or referenced after `gpu.RenderPass.end()` is called.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const RenderPass = packed struct {
    value: *C.SDL_GPURenderPass,
};

/// Specifies the sample count of a texture.
///
/// ## Remarks
/// Used in multisampling.
/// Note that this value only applies when the texture is used as a render target.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const SampleCount = enum(c_uint) {
    no_multisampling = C.SDL_GPU_SAMPLECOUNT_1,
    msaa_2x = C.SDL_GPU_SAMPLECOUNT_2,
    msaa_4x = C.SDL_GPU_SAMPLECOUNT_4,
    msaa_8x = C.SDL_GPU_SAMPLECOUNT_8,
};

/// An opaque handle representing a sampler.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const Sampler = packed struct {
    value: *C.SDL_GPUSampler,
};

/// Specifies behavior of texture sampling when the coordinates exceed the 0-1 range.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const SamplerAddressMode = enum(c_uint) {
    /// Specifies that the coordinates will wrap around.
    repeat = C.SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
    /// Specifies that the coordinates will wrap around mirrored.
    mirrored_repeat = C.SDL_GPU_SAMPLERADDRESSMODE_MIRRORED_REPEAT,
    /// Specifies that the coordinates will clamp to the 0-1 range.
    clamp_to_edge = C.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
};

/// Specifies a mipmap mode used by a sampler.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const SamplerMipmapMode = enum(c_uint) {
    /// Point filtering.
    nearest = C.SDL_GPU_SAMPLERMIPMAPMODE_NEAREST,
    /// Linear filtering.
    linear = C.SDL_GPU_SAMPLERMIPMAPMODE_LINEAR,
};

/// An opaque handle representing a compiled shader object.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const Shader = packed struct {
    value: *C.SDL_GPUShader,
};

/// Specifies the format of shader code.
///
/// ## Remarks
/// Each format corresponds to a specific backend that accepts it.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const ShaderFormat = enum(c_uint) {
    /// Shaders for NDA'd platforms.
    private = C.SDL_GPU_SHADERFORMAT_PRIVATE,
    /// SPIR-V shaders for Vulkan.
    spirv = C.SDL_GPU_SHADERFORMAT_SPIRV,
    /// DXBC SM5_1 shaders for D3D12.
    dxbc = C.SDL_GPU_SHADERFORMAT_DXBC,
    /// DXIL SM6_0 shaders for D3D12.
    dxil = C.SDL_GPU_SHADERFORMAT_DXIL,
    /// MSL shaders for Metal.
    msl = C.SDL_GPU_SHADERFORMAT_MSL,
    /// Precompiled metallib shaders for Metal.
    metal_lib = C.SDL_GPU_SHADERFORMAT_METALLIB,

    /// Convert from an SDL value.
    pub fn fromSdl(value: C.SDL_GPUShaderFormat) ?ShaderFormat {
        if (value == C.SDL_GPU_SHADERFORMAT_INVALID)
            return null;
        return @enumFromInt(value);
    }

    /// Convert to an SDL value.
    pub fn toSdl(self: ?ShaderFormat) C.SDL_GPUShaderFormat {
        if (self) |val| {
            return @intFromEnum(val);
        }
        return C.SDL_GPU_SHADERFORMAT_INVALID;
    }
};

/// Specifies which stage a shader program corresponds to.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const ShaderStage = enum(c_uint) {
    vertex = C.SDL_GPU_SHADERSTAGE_VERTEX,
    fragment = C.SDL_GPU_SHADERSTAGE_FRAGMENT,
};

/// Specifies what happens to a stored stencil value if stencil tests fail or pass.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const StencilOperation = enum(c_uint) {
    /// Keeps the current value.
    keep = C.SDL_GPU_STENCILOP_KEEP,
    /// Sets the value to 0.
    zero = C.SDL_GPU_STENCILOP_ZERO,
    /// Sets the value to reference.
    replace = C.SDL_GPU_STENCILOP_REPLACE,
    /// Increments the current value and clamps to the maximum value.
    increment_and_clamp = C.SDL_GPU_STENCILOP_INCREMENT_AND_CLAMP,
    /// Decrements the current value and clamps to 0.
    decrement_and_clamp = C.SDL_GPU_STENCILOP_DECREMENT_AND_CLAMP,
    /// Bitwise-inverts the current value.
    invert = C.SDL_GPU_STENCILOP_INVERT,
    /// Increments the current value and wraps back to 0.
    increment_and_wrap = C.SDL_GPU_STENCILOP_INCREMENT_AND_WRAP,
    /// Decrements the current value and wraps to the maximum value.
    decrement_and_wrap = C.SDL_GPU_STENCILOP_DECREMENT_AND_WRAP,

    /// Create from SDL.
    pub fn fromSdl(val: C.SDL_GPUStencilOp) ?StencilOperation {
        if (val == C.SDL_GPU_STENCILOP_INVALID) {
            return null;
        }
        return @enumFromInt(val);
    }

    /// Convert to an SDL value.
    pub fn toSdl(val: ?StencilOperation) C.SDL_GPUStencilOp {
        if (val) |tmp| {
            return @intFromEnum(tmp);
        }
        return C.SDL_GPU_STENCILOP_INVALID;
    }
};

/// Specifies how the contents of a texture attached to a render pass are treated at the end of the render pass.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const StoreOperation = enum(c_uint) {
    /// The contents generated during the render pass will be written to memory.
    store = C.SDL_GPU_STOREOP_STORE,
    /// The contents generated during the render pass are not needed and may be discarded.
    /// The contents will be undefined.
    do_not_care = C.SDL_GPU_STOREOP_DONT_CARE,
    /// The multisample contents generated during the render pass will be resolved to a non-multisample texture.
    /// The contents in the multisample texture may then be discarded and will be undefined.
    resolve = C.SDL_GPU_STOREOP_RESOLVE,
    /// The multisample contents generated during the render pass will be resolved to a non-multisample texture.
    /// The contents in the multisample texture will be written to memory.
    resolve_and_store = C.SDL_GPU_STOREOP_RESOLVE_AND_STORE,
};

/// Specifies the texture format and colorspace of the swapchain textures.
///
/// ## Remarks
/// `gpu.SwapchainComposition.sdr` will always be supported.
/// Other compositions may not be supported on certain systems.
///
/// It is recommended to query `video.Window.supportsGpuSwapchainComposition()` after claiming the window
/// if you wish to change the swapchain composition from `gpu.SwapchainComposition.sdr`.
pub const SwapchainComposition = enum(c_uint) {
    /// B8G8R8A8 or R8G8B8A8 swapchain.
    /// Pixel values are in sRGB encoding.
    sdr = C.SDL_GPU_SWAPCHAINCOMPOSITION_SDR,
    /// B8G8R8A8_SRGB or R8G8B8A8_SRGB swapchain.
    /// Pixel values are stored in memory in sRGB encoding but accessed in shaders in "linear sRGB" encoding which is sRGB but with a linear transfer function.
    sdr_linear = C.SDL_GPU_SWAPCHAINCOMPOSITION_SDR_LINEAR,
    /// R16G16B16A16_FLOAT swapchain.
    /// Pixel values are in extended linear sRGB encoding and permits values outside of the [0, 1] range.
    hdr_extended_linear = C.SDL_GPU_SWAPCHAINCOMPOSITION_HDR_EXTENDED_LINEAR,
    /// A2R10G10B10 or A2B10G10R10 swapchain.
    /// Pixel values are in BT.2020 ST2084 (PQ) encoding.
    hdr10_st2084 = C.SDL_GPU_SWAPCHAINCOMPOSITION_HDR10_ST2084,
};

/// An opaque handle representing a texture.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const Texture = packed struct {
    value: *C.SDL_GPUTexture,
};

/// Specifies the pixel format of a texture.
///
/// ## Remarks
/// Texture format support varies depending on driver, hardware, and usage flags.
/// In general, you should use `gpu.Device.textureSupportsFormat()` to query if a format is supported before using it.
/// However, there are a few guaranteed formats.
///
/// For `gpu.TextureUsageFlags.sampler` usage, the following formats are universally supported:
/// * r8g8b8a8_unorm
/// * b8g8r8a8_unorm
/// * r8_unorm
/// * r8_snorm
/// * r8g8_unorm
/// * r8g8_snorm
/// * r8g8b8a8_snorm
/// * r16_float
/// * r16g16_float
/// * r16g16b16a16_float
/// * r32_float
/// * r32g32_float
/// * r32g32b32a32_float
/// * r11g11b10_ufloat
/// * r8g8b8a8_unorm_srgb
/// * b8g8r8a8_unorm_srgb
/// * depth16_unorm
///
/// For `gpu.TextureUsageFlags.color_target` usage, the following formats are universally supported:
/// * r8g8b8a8_unorm
/// * b8g8r8a8_unorm
/// * r8_unorm
/// * r16_float
/// * r16g16_float
/// * r16g16b16a16_float
/// * r32_float
/// * r32g32_float
/// * r32g32b32a32_float
/// * r8_uint
/// * r8g8_uint
/// * r8g8b8a8_uint
/// * r16_uint
/// * r16g16_uint
/// * r16g16b16a16_uint
/// * r8_int
/// * r8g8_int
/// * r8g8b8a8_int
/// * r16_int
/// * r16g16_int
/// * r16g16b16a16_int
/// * r8g8b8a8_unorm_srgb
/// * b8g8r8a8_unorm_srgb
///
/// For `gpu.TextureUsageFlags.storage` usages, the following formats are universally supported:
/// * r8g8b8a8_unorm
/// * r8g8b8a8_snorm
/// * r16g16b16a16_float
/// * r32_float
/// * r32g32_float
/// * r32g32b32a32_float
/// * r8g8b8a8_uint
/// * r16g16b16a16_uint
/// * r8g8b8a8_int
/// * r16g16b16a16_int
///
/// For `gpu.TextureUsageFlags.depth_stencil_target` usage, the following formats are universally supported:
/// * depth16_unorm
/// * Either (but not necessarily both!) depth24_unorm or depth32_float
/// * Either (but not necessarily both!) depth24_unorm_s8_uint or depth32_float_s8_uint
///
/// Unless `gpu.TextureFormat.depth16_unorm` is sufficient for your purposes, always check which of depth24/depth32 is supported before creating a depth-stencil texture!
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const TextureFormat = enum(c_uint) {
    a8_unorm = C.SDL_GPU_TEXTUREFORMAT_A8_UNORM,
    r8_unorm = C.SDL_GPU_TEXTUREFORMAT_R8_UNORM,
    r8g8_unorm = C.SDL_GPU_TEXTUREFORMAT_R8G8_UNORM,
    r8g8b8a8_unorm = C.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
    r16_unorm = C.SDL_GPU_TEXTUREFORMAT_R16_UNORM,
    r16g16_unorm = C.SDL_GPU_TEXTUREFORMAT_R16G16_UNORM,
    r16g16b16a16_unorm = C.SDL_GPU_TEXTUREFORMAT_R16G16B16A16_UNORM,
    r10g10b10a2_unorm = C.SDL_GPU_TEXTUREFORMAT_R10G10B10A2_UNORM,
    b5g6r5_unorm = C.SDL_GPU_TEXTUREFORMAT_B5G6R5_UNORM,
    b5g5r5a1_unorm = C.SDL_GPU_TEXTUREFORMAT_B5G5R5A1_UNORM,
    b4g4r4a4_unorm = C.SDL_GPU_TEXTUREFORMAT_B4G4R4A4_UNORM,
    b8g8r8a8_unorm = C.SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM,
    bc1_rgba_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_BC1_RGBA_UNORM,
    bc2_rgba_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_BC2_RGBA_UNORM,
    bc3_rgba_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_BC3_RGBA_UNORM,
    bc4_r_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_BC4_R_UNORM,
    bc5_rg_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_BC5_RG_UNORM,
    bc7_rgba_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_BC7_RGBA_UNORM,
    bc6h_rgb_float_compressed = C.SDL_GPU_TEXTUREFORMAT_BC6H_RGB_FLOAT,
    bc6h_rgb_ufloat_compressed = C.SDL_GPU_TEXTUREFORMAT_BC6H_RGB_UFLOAT,
    r8_snorm = C.SDL_GPU_TEXTUREFORMAT_R8_SNORM,
    r8g8_snorm = C.SDL_GPU_TEXTUREFORMAT_R8G8_SNORM,
    r8g8b8a8_snorm = C.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_SNORM,
    r16_snorm = C.SDL_GPU_TEXTUREFORMAT_R16_SNORM,
    r16g16_snorm = C.SDL_GPU_TEXTUREFORMAT_R16G16_SNORM,
    r16g16b16a16_snorm = C.SDL_GPU_TEXTUREFORMAT_R16G16B16A16_SNORM,
    r16_float = C.SDL_GPU_TEXTUREFORMAT_R16_FLOAT,
    r16g16_float = C.SDL_GPU_TEXTUREFORMAT_R16G16_FLOAT,
    r16g16b16a16_float = C.SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT,
    r32_float = C.SDL_GPU_TEXTUREFORMAT_R32_FLOAT,
    r32g32_float = C.SDL_GPU_TEXTUREFORMAT_R32G32_FLOAT,
    r32g32b32a32_float = C.SDL_GPU_TEXTUREFORMAT_R32G32B32A32_FLOAT,
    r11g11b10_ufloat = C.SDL_GPU_TEXTUREFORMAT_R11G11B10_UFLOAT,
    r8_uint = C.SDL_GPU_TEXTUREFORMAT_R8_UINT,
    r8g8_uint = C.SDL_GPU_TEXTUREFORMAT_R8G8_UINT,
    r8g8b8a8_uint = C.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UINT,
    r16_uint = C.SDL_GPU_TEXTUREFORMAT_R16_UINT,
    r16g16_uint = C.SDL_GPU_TEXTUREFORMAT_R16G16_UINT,
    r16g16b16a16_uint = C.SDL_GPU_TEXTUREFORMAT_R16G16B16A16_UINT,
    r32_uint = C.SDL_GPU_TEXTUREFORMAT_R32_UINT,
    r32g32_uint = C.SDL_GPU_TEXTUREFORMAT_R32G32_UINT,
    r32g32b32a32_uint = C.SDL_GPU_TEXTUREFORMAT_R32G32B32A32_UINT,
    r8_int = C.SDL_GPU_TEXTUREFORMAT_R8_INT,
    r8g8_int = C.SDL_GPU_TEXTUREFORMAT_R8G8_INT,
    r8g8b8a8_int = C.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_INT,
    r16_int = C.SDL_GPU_TEXTUREFORMAT_R16_INT,
    r16g16_int = C.SDL_GPU_TEXTUREFORMAT_R16G16_INT,
    r16g16b16a16_int = C.SDL_GPU_TEXTUREFORMAT_R16G16B16A16_INT,
    r32_int = C.SDL_GPU_TEXTUREFORMAT_R32_INT,
    r32g32_int = C.SDL_GPU_TEXTUREFORMAT_R32G32_INT,
    r32g32b32a32_int = C.SDL_GPU_TEXTUREFORMAT_R32G32B32A32_INT,
    r8g8b8a8_unorm_srgb = C.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM_SRGB,
    b8g8r8a8_unorm_srgb = C.SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM_SRGB,
    bc1_rgba_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_BC1_RGBA_UNORM_SRGB,
    bc2_rgba_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_BC2_RGBA_UNORM_SRGB,
    bc3_rgba_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_BC3_RGBA_UNORM_SRGB,
    bc7_rgba_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_BC7_RGBA_UNORM_SRGB,
    depth16_unorm = C.SDL_GPU_TEXTUREFORMAT_D16_UNORM,
    depth24_unorm = C.SDL_GPU_TEXTUREFORMAT_D24_UNORM,
    depth32_float = C.SDL_GPU_TEXTUREFORMAT_D32_FLOAT,
    depth24_unorm_s8_uint = C.SDL_GPU_TEXTUREFORMAT_D24_UNORM_S8_UINT,
    depth32_float_s8_uint = C.SDL_GPU_TEXTUREFORMAT_D32_FLOAT_S8_UINT,
    astc_4x4_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_4x4_UNORM,
    astc_5x4_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_5x4_UNORM,
    astc_5x5_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_5x5_UNORM,
    astc_6x5_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_6x5_UNORM,
    astc_6x6_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_6x6_UNORM,
    astc_8x5_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_8x5_UNORM,
    astc_8x6_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_8x6_UNORM,
    astc_8x8_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_8x8_UNORM,
    astc_10x5_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_10x5_UNORM,
    astc_10x6_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_10x6_UNORM,
    astc_10x8_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_10x8_UNORM,
    astc_10x10_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_10x10_UNORM,
    astc_12x10_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_12x10_UNORM,
    astc_12x12_unorm_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_12x12_UNORM,
    astc_4x4_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_4x4_UNORM_SRGB,
    astc_5x4_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_5x4_UNORM_SRGB,
    astc_5x5_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_5x5_UNORM_SRGB,
    astc_6x5_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_6x5_UNORM_SRGB,
    astc_6x6_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_6x6_UNORM_SRGB,
    astc_8x5_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_8x5_UNORM_SRGB,
    astc_8x6_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_8x6_UNORM_SRGB,
    astc_8x8_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_8x8_UNORM_SRGB,
    astc_10x5_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_10x5_UNORM_SRGB,
    astc_10x6_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_10x6_UNORM_SRGB,
    astc_10x8_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_10x8_UNORM_SRGB,
    astc_10x10_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_10x10_UNORM_SRGB,
    astc_12x10_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_12x10_UNORM_SRGB,
    astc_12x12_unorm_srgb_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_12x12_UNORM_SRGB,
    astc_4x4_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_4x4_FLOAT,
    astc_5x4_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_5x4_FLOAT,
    astc_5x5_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_5x5_FLOAT,
    astc_6x5_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_6x5_FLOAT,
    astc_6x6_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_6x6_FLOAT,
    astc_8x5_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_8x5_FLOAT,
    astc_8x6_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_8x6_FLOAT,
    astc_8x8_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_8x8_FLOAT,
    astc_10x5_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_10x5_FLOAT,
    astc_10x6_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_10x6_FLOAT,
    astc_10x8_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_10x8_FLOAT,
    astc_10x10_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_10x10_FLOAT,
    astc_12x10_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_12x10_FLOAT,
    astc_12x12_float_compressed = C.SDL_GPU_TEXTUREFORMAT_ASTC_12x12_FLOAT,
};

/// Specifies the type of a texture.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const TextureType = enum(c_uint) {
    /// The texture is a 2-dimensional image.
    two_dimensional = C.SDL_GPU_TEXTURETYPE_2D,
    /// The texture is a 2-dimensional array image.
    two_dimensional_array = C.SDL_GPU_TEXTURETYPE_2D_ARRAY,
    /// The texture is a 3-dimensional image.
    three_dimensional = C.SDL_GPU_TEXTURETYPE_3D,
    /// The texture is a cube image.
    cube = C.SDL_GPU_TEXTURETYPE_CUBE,
    /// The texture is a cube array image.
    cube_array = C.SDL_GPU_TEXTURETYPE_CUBE_ARRAY,
};

/// Specifies how a texture is intended to be used by the client.
///
/// ## Remarks
/// A texture must have at least one usage flag.
/// Note that some usage flag combinations are invalid.
///
/// With regards to compute storage usage, READ | WRITE means that you can have shader A that only writes into the texture
/// and shader B that only reads from the texture and bind the same texture to either shader respectively.
/// SIMULTANEOUS means that you can do reads and writes within the same shader or compute pass.
/// It also implies that atomic ops can be used, since those are read-modify-write operations.
/// If you use SIMULTANEOUS, you are responsible for avoiding data races, as there is no data synchronization within a compute pass.
/// Note that SIMULTANEOUS usage is only supported by a limited number of texture formats.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const TextureUsageFlags = struct {
    /// Texture supports sampling.
    sampler: bool = false,
    /// Texture is a color render target.
    color_target: bool = false,
    /// Texture is a depth stencil target.
    depth_stencil_target: bool = false,
    /// Texture supports storage reads in graphics stages.
    graphics_storage_read: bool = false,
    /// Texture supports storage reads in the compute stage.
    compute_storage_read: bool = false,
    /// Texture supports storage writes in the compute stage.
    compute_storage_write: bool = false,
    /// Texture supports reads and writes in the same compute shader. This is NOT equivalent to READ | WRITE.
    compute_storage_simultaneous_read_write: bool = false,

    /// Convert from SDL.
    pub fn fromSdl(value: C.SDL_GPUTextureUsageFlags) TextureUsageFlags {
        return .{
            .sampler = value & C.SDL_GPU_TEXTUREUSAGE_SAMPLER > 0,
            .color_target = value & C.SDL_GPU_TEXTUREUSAGE_COLOR_TARGET > 0,
            .depth_stencil_target = value & C.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET > 0,
            .graphics_storage_read = value & C.SDL_GPU_TEXTUREUSAGE_GRAPHICS_STORAGE_READ > 0,
            .compute_storage_read = value & C.SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_READ > 0,
            .compute_storage_write = value & C.SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_WRITE > 0,
            .compute_storage_simultaneous_read_write = value & C.SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_SIMULTANEOUS_READ_WRITE > 0,
        };
    }

    /// Convert to an SDL value.
    pub fn toSdl(self: TextureUsageFlags) C.SDL_GPUTextureUsageFlags {
        var ret: C.SDL_GPUTextureUsageFlags = 0;
        if (self.sampler)
            ret |= C.SDL_GPU_TEXTUREUSAGE_SAMPLER;
        if (self.color_target)
            ret |= C.SDL_GPU_TEXTUREUSAGE_COLOR_TARGET;
        if (self.depth_stencil_target)
            ret |= C.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET;
        if (self.graphics_storage_read)
            ret |= C.SDL_GPU_TEXTUREUSAGE_GRAPHICS_STORAGE_READ;
        if (self.compute_storage_read)
            ret |= C.SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_READ;
        if (self.compute_storage_write)
            ret |= C.SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_WRITE;
        if (self.compute_storage_simultaneous_read_write)
            ret |= C.SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_SIMULTANEOUS_READ_WRITE;
        return ret;
    }
};

/// An opaque handle representing a transfer buffer.
///
/// ## Remarks
/// Used for transferring data to and from the device.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const TransferBuffer = struct {
    value: *C.SDL_GPUTransferBuffer,
};

/// Specifies how a transfer buffer is intended to be used by the client.
///
/// ## Remarks
/// Note that mapping and copying **from** an upload transfer buffer or **to** a download transfer buffer is undefined behavior.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const TransferBufferUsage = enum(c_uint) {
    upload = C.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
    download = C.SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD,
};

/// Specifies the format of a vertex attribute.
///
/// ## Remarks
/// Format is by type times quantity (`gpu.VertexElementFormat.u32x2` means 2 32-bit unsigned integers).
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const VertexElementFormat = enum(c_uint) {
    i32x1 = C.SDL_GPU_VERTEXELEMENTFORMAT_INT,
    i32x2 = C.SDL_GPU_VERTEXELEMENTFORMAT_INT2,
    i32x3 = C.SDL_GPU_VERTEXELEMENTFORMAT_INT3,
    i32x4 = C.SDL_GPU_VERTEXELEMENTFORMAT_INT4,
    u32x1 = C.SDL_GPU_VERTEXELEMENTFORMAT_UINT,
    u32x2 = C.SDL_GPU_VERTEXELEMENTFORMAT_UINT2,
    u32x3 = C.SDL_GPU_VERTEXELEMENTFORMAT_UINT3,
    u32x4 = C.SDL_GPU_VERTEXELEMENTFORMAT_UINT4,
    f32x1 = C.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT,
    f32x2 = C.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
    f32x3 = C.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
    f32x4 = C.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
    i8x2 = C.SDL_GPU_VERTEXELEMENTFORMAT_BYTE2,
    i8x4 = C.SDL_GPU_VERTEXELEMENTFORMAT_BYTE4,
    u8x2 = C.SDL_GPU_VERTEXELEMENTFORMAT_UBYTE2,
    u8x4 = C.SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4,
    i8x2_normalized = C.SDL_GPU_VERTEXELEMENTFORMAT_BYTE2_NORM,
    i8x4_normalized = C.SDL_GPU_VERTEXELEMENTFORMAT_BYTE4_NORM,
    u8x2_normalized = C.SDL_GPU_VERTEXELEMENTFORMAT_UBYTE2_NORM,
    u8x4_normalized = C.SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4_NORM,
    i16x2 = C.SDL_GPU_VERTEXELEMENTFORMAT_SHORT2,
    i16x4 = C.SDL_GPU_VERTEXELEMENTFORMAT_SHORT4,
    u16x2 = C.SDL_GPU_VERTEXELEMENTFORMAT_USHORT2,
    u16x4 = C.SDL_GPU_VERTEXELEMENTFORMAT_USHORT4,
    i16x2_normalized = C.SDL_GPU_VERTEXELEMENTFORMAT_SHORT2_NORM,
    i16x4_normalized = C.SDL_GPU_VERTEXELEMENTFORMAT_SHORT4_NORM,
    u16x2_normalized = C.SDL_GPU_VERTEXELEMENTFORMAT_USHORT2_NORM,
    u16x4_normalized = C.SDL_GPU_VERTEXELEMENTFORMAT_USHORT4_NORM,
    f16x2 = C.SDL_GPU_VERTEXELEMENTFORMAT_HALF2,
    f16x4 = C.SDL_GPU_VERTEXELEMENTFORMAT_HALF4,

    /// Create from SDL.
    pub fn fromSdl(val: C.SDL_GPUVertexElementFormat) ?VertexElementFormat {
        if (val == C.SDL_GPU_VERTEXELEMENTFORMAT_INVALID) {
            return null;
        }
        return @enumFromInt(val);
    }

    /// Convert to an SDL value.
    pub fn toSdl(val: ?VertexElementFormat) C.SDL_GPUVertexElementFormat {
        if (val) |tmp| {
            return @intFromEnum(tmp);
        }
        return C.SDL_GPU_VERTEXELEMENTFORMAT_INVALID;
    }
};

/// Specifies the rate at which vertex attributes are pulled from buffers.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const VertexInputRate = enum(c_uint) {
    /// Attribute addressing is a function of the vertex index.
    vertex = C.SDL_GPU_VERTEXINPUTRATE_VERTEX,
    /// Attribute addressing is a function of the instance index.
    instance = C.SDL_GPU_VERTEXINPUTRATE_INSTANCE,
};

// Test the GPU.
test "Gpu" {
    comptime try std.testing.expectEqual(@sizeOf(C.SDL_GPUColorComponentFlags), @sizeOf(ColorComponentFlags));
    comptime try std.testing.expectEqual(C.SDL_GPU_COLORCOMPONENT_R, @as(C.SDL_GPUColorComponentFlags, @bitCast(ColorComponentFlags{ .red = true })));
    comptime try std.testing.expectEqual(C.SDL_GPU_COLORCOMPONENT_G, @as(C.SDL_GPUColorComponentFlags, @bitCast(ColorComponentFlags{ .green = true })));
    comptime try std.testing.expectEqual(C.SDL_GPU_COLORCOMPONENT_B, @as(C.SDL_GPUColorComponentFlags, @bitCast(ColorComponentFlags{ .blue = true })));
    comptime try std.testing.expectEqual(C.SDL_GPU_COLORCOMPONENT_A, @as(C.SDL_GPUColorComponentFlags, @bitCast(ColorComponentFlags{ .alpha = true })));

    comptime try std.testing.expectEqual(@sizeOf(C.SDL_GPUBufferBinding), @sizeOf(BufferBinding));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUBufferBinding, "buffer")), @sizeOf(@FieldType(BufferBinding, "buffer")));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUBufferBinding, "buffer"), @offsetOf(BufferBinding, "buffer"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUBufferBinding, "offset")), @sizeOf(@FieldType(BufferBinding, "offset")));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUBufferBinding, "offset"), @offsetOf(BufferBinding, "offset"));

    comptime try std.testing.expectEqual(@sizeOf(C.SDL_GPUColorTargetBlendState), @sizeOf(ColorTargetBlendState));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUColorTargetBlendState, "src_color_blendfactor"), @offsetOf(ColorTargetBlendState, "source_color"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUColorTargetBlendState, "src_color_blendfactor")), @sizeOf(@FieldType(ColorTargetBlendState, "source_color")));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUColorTargetBlendState, "dst_color_blendfactor"), @offsetOf(ColorTargetBlendState, "destination_color"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUColorTargetBlendState, "dst_color_blendfactor")), @sizeOf(@FieldType(ColorTargetBlendState, "destination_color")));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUColorTargetBlendState, "color_blend_op"), @offsetOf(ColorTargetBlendState, "color_blend"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUColorTargetBlendState, "color_blend_op")), @sizeOf(@FieldType(ColorTargetBlendState, "color_blend")));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUColorTargetBlendState, "src_alpha_blendfactor"), @offsetOf(ColorTargetBlendState, "source_alpha"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUColorTargetBlendState, "src_alpha_blendfactor")), @sizeOf(@FieldType(ColorTargetBlendState, "source_alpha")));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUColorTargetBlendState, "dst_alpha_blendfactor"), @offsetOf(ColorTargetBlendState, "destination_alpha"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUColorTargetBlendState, "dst_alpha_blendfactor")), @sizeOf(@FieldType(ColorTargetBlendState, "destination_alpha")));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUColorTargetBlendState, "alpha_blend_op"), @offsetOf(ColorTargetBlendState, "alpha_blend"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUColorTargetBlendState, "alpha_blend_op")), @sizeOf(@FieldType(ColorTargetBlendState, "alpha_blend")));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUColorTargetBlendState, "color_write_mask"), @offsetOf(ColorTargetBlendState, "color_write_mask"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUColorTargetBlendState, "color_write_mask")), @sizeOf(@FieldType(ColorTargetBlendState, "color_write_mask")));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUColorTargetBlendState, "enable_blend"), @offsetOf(ColorTargetBlendState, "enable_blend"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUColorTargetBlendState, "enable_blend")), @sizeOf(@FieldType(ColorTargetBlendState, "enable_blend")));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUColorTargetBlendState, "enable_color_write_mask"), @offsetOf(ColorTargetBlendState, "enable_color_write_mask"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUColorTargetBlendState, "enable_color_write_mask")), @sizeOf(@FieldType(ColorTargetBlendState, "enable_color_write_mask")));

    comptime try std.testing.expectEqual(@sizeOf(C.SDL_GPUColorTargetDescription), @sizeOf(ColorTargetDescription));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUColorTargetDescription, "format"), @offsetOf(ColorTargetDescription, "format"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUColorTargetDescription, "format")), @sizeOf(@FieldType(ColorTargetDescription, "format")));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_GPUColorTargetDescription, "blend_state"), @offsetOf(ColorTargetDescription, "blend_state"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_GPUColorTargetDescription, "blend_state")), @sizeOf(@FieldType(ColorTargetDescription, "blend_state")));
}
