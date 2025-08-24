const c = @import("c");
const errors = @import("errors.zig");
const gpu = @import("gpu.zig");
const properties = @import("properties.zig");
const std = @import("std");

/// Version of SDL shadercross to use.
///
/// ## Version
/// This constant is provided by SDL3 shadercross.
pub const version: struct {
    major: u32,
    minor: u32,
    micro: u32,
} = .{
    .major = c.SDL_SHADERCROSS_MAJOR_VERSION,
    .minor = c.SDL_SHADERCROSS_MINOR_VERSION,
    .micro = c.SDL_SHADERCROSS_MICRO_VERSION,
};

/// Compute pipeline metadata.
///
/// ## Version
/// This struct is provided by SDL3 shadercross.
pub const ComputePipelineMetadata = extern struct {
    /// The number of samplers defined in the shader.
    num_samplers: u32,
    /// The number of readonly storage textures defined in the shader.
    num_readonly_storage_textures: u32,
    /// The number of readonly storage buffers defined in the shader.
    num_readonly_storage_buffers: u32,
    /// The number of read-write storage textures defined in the shader.
    num_readwrite_storage_textures: u32,
    /// The number of read-write storage buffers defined in the shader.
    num_readwrite_storage_buffers: u32,
    /// The number of uniform buffers defined in the shader.
    num_uniform_buffers: u32,
    /// The number of threads in the X dimension.
    threadcount_x: u32,
    /// The number of threads in the Y dimension.
    threadcount_y: u32,
    /// The number of threads in the Z dimension.
    threadcount_z: u32,

    // Size tests.
    comptime {
        errors.assertStructsEqual(ComputePipelineMetadata, c.SDL_ShaderCross_ComputePipelineMetadata);
    }
};

/// Metadata for an IO variable.
///
/// ## Version
/// This enum is provided by SDL3 shadercross.
pub const IoVarMetadata = extern struct {
    /// The UTF-8 name of the variable.
    name: [*:0]const u8,
    /// The location of the variable.
    location: u32,
    /// The vector type of the variable.
    vector_type: IoVarType,
    /// The number of components in the vector type of the variable.
    vector_size: u32,

    // Size test.
    comptime {
        errors.assertStructsEqual(IoVarMetadata, c.SDL_ShaderCross_IOVarMetadata);
    }
};

/// Type of IO variable.
///
/// ## Version
/// This enum is provided by SDL3 shadercross.
pub const IoVarType = enum(c_uint) {
    i8 = c.SDL_SHADERCROSS_IOVAR_TYPE_INT8,
    u8 = c.SDL_SHADERCROSS_IOVAR_TYPE_UINT8,
    i16 = c.SDL_SHADERCROSS_IOVAR_TYPE_INT16,
    u16 = c.SDL_SHADERCROSS_IOVAR_TYPE_UINT16,
    i32 = c.SDL_SHADERCROSS_IOVAR_TYPE_INT32,
    u32 = c.SDL_SHADERCROSS_IOVAR_TYPE_UINT32,
    i64 = c.SDL_SHADERCROSS_IOVAR_TYPE_INT64,
    u64 = c.SDL_SHADERCROSS_IOVAR_TYPE_UINT64,
    f16 = c.SDL_SHADERCROSS_IOVAR_TYPE_FLOAT16,
    f32 = c.SDL_SHADERCROSS_IOVAR_TYPE_FLOAT32,
    f64 = c.SDL_SHADERCROSS_IOVAR_TYPE_FLOAT64,

    /// Convert from SDL.
    pub fn fromSdl(value: c.SDL_ShaderCross_IOVarType) ?IoVarType {
        if (value == c.SDL_SHADERCROSS_IOVAR_TYPE_UNKNOWN)
            return null;
        return @enumFromInt(value);
    }

    /// Convert to an SDL value.
    pub fn toSdl(self: ?IoVarType) c.SDL_ShaderCross_IOVarType {
        if (self) |val| {
            return @intFromEnum(val);
        }
        return c.SDL_SHADERCROSS_IOVAR_TYPE_UNKNOWN;
    }
};

/// Metadata used for the graphics shader stage.
///
/// ## Version
/// This struct is provided by SDL3 shadercross.
pub const GraphicsShaderMetadata = struct {
    /// The number of samplers defined in the shader.
    num_samplers: u32,
    /// The number of storage textures defined in the shader.
    num_storage_textures: u32,
    /// The number of storage buffers defined in the shader.
    num_storage_buffers: u32,
    /// The number of uniform buffers defined in the shader.
    num_uniform_buffers: u32,
    /// The inputs defined in the shader.
    inputs: []IoVarMetadata,
    /// The outputs defined in the shader.
    outputs: []IoVarMetadata,

    /// Convert from SDL.
    pub fn fromSdl(value: c.SDL_ShaderCross_GraphicsShaderMetadata) GraphicsShaderMetadata {
        return .{
            .num_samplers = value.num_samplers,
            .num_storage_textures = value.num_storage_textures,
            .num_storage_buffers = value.num_storage_buffers,
            .num_uniform_buffers = value.num_uniform_buffers,
            .inputs = @as([*]IoVarMetadata, @ptrCast(value.inputs))[0..@intCast(value.num_inputs)],
            .outputs = @as([*]IoVarMetadata, @ptrCast(value.outputs))[0..@intCast(value.num_outputs)],
        };
    }

    /// Convert to SDL.
    pub fn toSdl(self: GraphicsShaderMetadata) c.SDL_ShaderCross_GraphicsShaderMetadata {
        return .{
            .num_samplers = self.num_samplers,
            .num_storage_textures = self.num_storage_textures,
            .num_storage_buffers = self.num_storage_buffers,
            .num_uniform_buffers = self.num_uniform_buffers,
            .num_inputs = @intCast(self.inputs.len),
            .inputs = @ptrCast(self.inputs.ptr),
            .num_outputs = @intCast(self.outputs.len),
            .outputs = @ptrCast(self.outputs.ptr),
        };
    }
};

/// An HLSL define.
///
/// ## Version
/// This struct is provided by SDL3 shadercross.
pub const HlslDefine = extern struct {
    /// The define name.
    /// Should only be `null` for the terminator of defines.
    name: ?[*:0]u8,
    /// An optional value for the define, can be `null`.
    value: ?[*:0]u8,

    // Size tests.
    comptime {
        errors.assertStructsEqual(HlslDefine, c.SDL_ShaderCross_HLSL_Define);
    }
};

/// HLSL information.
///
/// ## Version
/// This struct is provided by SDL3 shadercross.
pub const HlslInfo = struct {
    /// The HLSL source code for the shader.
    source: [:0]const u8,
    /// The entry point function name for the shader in UTF-8.
    entry_point: [:0]const u8,
    /// The include directory for shader code.
    include_dir: ?[:0]const u8,
    /// An array of defines, can be `null`.
    /// If not `null`, must be terminated with a fully `null` define struct.
    defines: ?[*]HlslDefine,
    /// The shader stage to compile the shader with.
    shader_stage: ShaderStage,
    /// Allows debug info to be emitted when relevant.
    /// Can be useful for graphics debuggers like RenderDoc.
    enable_debug: bool,
    /// A UTF-8 name to associate with the shader.
    name: ?[:0]const u8,

    /// Convert to SDL.
    pub fn toSdl(self: HlslInfo) c.SDL_ShaderCross_HLSL_Info {
        return .{
            .source = self.source.ptr,
            .entrypoint = self.entry_point.ptr,
            .include_dir = if (self.include_dir) |val| val.ptr else null,
            .defines = if (self.defines) |val| @ptrCast(val) else null,
            .shader_stage = @intFromEnum(self.shader_stage),
            .enable_debug = self.enable_debug,
            .name = if (self.name) |val| val.ptr else null,
        };
    }
};

/// Shader stage.
///
/// ## Version
/// This enum is provided by SDL3 shadercross.
pub const ShaderStage = enum(c_uint) {
    vertex = c.SDL_SHADERCROSS_SHADERSTAGE_VERTEX,
    fragment = c.SDL_SHADERCROSS_SHADERSTAGE_FRAGMENT,
    compute = c.SDL_SHADERCROSS_SHADERSTAGE_COMPUTE,
};

/// SPIR-V cross-compilation info.
///
/// ## Version
/// This struct is provided by SDL3 shadercross.
pub const SpirvInfo = struct {
    /// The SPIRV bytecode.
    bytecode: []const u8,
    /// The entry point function name for the shader in UTF-8.
    entry_point: [:0]const u8,
    /// The shader stage to transpile the shader with.
    shader_stage: ShaderStage,
    /// Allows debug info to be emitted when relevant.
    /// Can be useful for graphics debuggers like RenderDoc.
    enable_debug: bool,
    /// A UTF-8 name to associate with the shader.
    name: ?[:0]const u8,
    /// Properties for extensions.
    props: ?Properties = null,

    /// Properties for the SPIRV info.
    ///
    /// ## Version
    /// This struct is provided by zig-sdl3.
    pub const Properties = struct {
        pssl_compatibility: ?bool,
        msl_version: ?[:0]const u8,

        /// Convert to SDL.
        pub fn toProperties(
            self: Properties,
        ) !properties.Group {
            const ret = try properties.Group.init();
            if (self.pssl_compatibility) |val|
                try ret.set(c.SDL_SHADERCROSS_PROP_SPIRV_PSSL_COMPATIBILITY, .{ .boolean = val });
            if (self.msl_version) |val|
                try ret.set(c.SDL_SHADERCROSS_PROP_SPIRV_MSL_VERSION, .{ .string = val });
            return ret;
        }
    };

    /// To an SDL value.
    pub fn toSdl(self: SpirvInfo) c.SDL_ShaderCross_SPIRV_Info {
        return .{
            .bytecode = self.bytecode.ptr,
            .bytecode_size = self.bytecode.len,
            .entrypoint = self.entry_point.ptr,
            .shader_stage = @intFromEnum(self.shader_stage),
            .enable_debug = self.enable_debug,
            .name = if (self.name) |val| val.ptr else null,
            .props = 0,
        };
    }
};

/// Compile to DXBC bytecode from HLSL code via a SPIRV-Cross round trip.
///
/// ## Function Parameters
/// * `info`: The shader to transpile.
///
/// ## Return Value
/// Returns the DXBC bytecode.
/// This needs to be freed with `free()`.
///
/// ## Remarks
/// You must `free()` the returned buffer once you are done with it.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn compileDxbcFromHlsl(
    info: HlslInfo,
) ![]u8 {
    const info_sdl = info.toSdl();
    var size: usize = undefined;
    return @as([*]u8, @ptrCast(try errors.wrapCallNull(*anyopaque, c.SDL_ShaderCross_CompileDXBCFromHLSL(&info_sdl, &size))))[0..@intCast(size)];
}

/// Compile to DXIL bytecode from HLSL code via a SPIRV-Cross round trip.
///
/// ## Function Parameters
/// * `info`: The shader to transpile.
///
/// ## Return Value
/// Returns the DXIL bytecode.
/// This needs to be freed with `free()`.
///
/// ## Remarks
/// You must `free()` the returned buffer once you are done with it.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn compileDxilFromHlsl(
    info: HlslInfo,
) ![]u8 {
    const info_sdl = info.toSdl();
    var size: usize = undefined;
    return @as([*]u8, @ptrCast(try errors.wrapCallNull(*anyopaque, c.SDL_ShaderCross_CompileDXILFromHLSL(&info_sdl, &size))))[0..@intCast(size)];
}

/// Compile DXBC bytecode from SPIRV code.
///
/// ## Function Parameters
/// * `info`: The shader to transpile.
///
/// ## Return Value
/// Returns the DXBC bytecode.
/// This needs to be freed with `free()`.
///
/// ## Remarks
/// You must `free()` the returned buffer once you are done with it.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn compileDxbcFromSpirv(
    info: SpirvInfo,
) ![]u8 {
    const info_sdl = info.toSdl();
    var size: usize = undefined;
    return @as([*]u8, @ptrCast(try errors.wrapCallNull(*anyopaque, c.SDL_ShaderCross_CompileDXBCFromSPIRV(&info_sdl, &size))))[0..@intCast(size)];
}

/// Compile DXIL bytecode from SPIRV code.
///
/// ## Function Parameters
/// * `info`: The shader to transpile.
///
/// ## Return Value
/// Returns the DXIL bytecode.
/// This needs to be freed with `free()`.
///
/// ## Remarks
/// You must `free()` the returned buffer once you are done with it.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn compileDxilFromSpirv(
    info: SpirvInfo,
) ![]u8 {
    const info_sdl = info.toSdl();
    var size: usize = undefined;
    return @as([*]u8, @ptrCast(try errors.wrapCallNull(*anyopaque, c.SDL_ShaderCross_CompileDXILFromSPIRV(&info_sdl, &size))))[0..@intCast(size)];
}

/// Compile an SDL GPU compute pipeline from SPIRV code.
///
/// ## Function Parameters
/// * `device`: The SDL GPU device.
/// * `info`: The shader to transpile.
/// * `metadata`: Shader metadata, can be obtained via `reflectGraphicsSpirv()`.
///
/// ## Return Value
/// A compiled GPU pipeline.
///
/// ## Remarks
/// If your shader source is HLSL, you should obtain SPIR-V bytecode from `compileSpirvFromHlsl()`.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn compileComputePipelineFromSpirv(
    device: gpu.Device,
    info: SpirvInfo,
    metadata: ComputePipelineMetadata,
) !gpu.ComputePipeline {
    const info_sdl = info.toSdl();
    return .{ .value = try errors.wrapCallNull(*c.SDL_GPUComputePipeline, c.SDL_ShaderCross_CompileComputePipelineFromSPIRV(device.value, &info_sdl, @ptrCast(&metadata), 0)) };
}

/// Compile an SDL GPU shader from SPIRV code.
///
/// ## Function Parameters
/// * `device`: The SDL GPU device.
/// * `info`: The shader to transpile.
/// * `metadata`: Shader metadata, can be obtained via `reflectGraphicsSpirv()`.
///
/// ## Return Value
/// A compiled GPU shader.
///
/// ## Remarks
/// If your shader source is HLSL, you should obtain SPIR-V bytecode from `compileSpirvFromHlsl()`.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn compileGraphicsShaderFromSpirv(
    device: gpu.Device,
    info: SpirvInfo,
    metadata: GraphicsShaderMetadata,
) !gpu.Shader {
    const info_sdl = info.toSdl();
    const metadata_sdl = metadata.toSdl();
    return .{ .value = try errors.wrapCallNull(*c.SDL_GPUShader, c.SDL_ShaderCross_CompileGraphicsShaderFromSPIRV(device.value, &info_sdl, &metadata_sdl, 0)) };
}

/// Compile to SPIRV bytecode from HLSL code.
///
/// ## Function Parameters
/// * `info`: The shader to transpile.
///
/// ## Return Value
/// Returns the SPIRV bytecode.
/// This needs to be freed with `free()`.
///
/// ## Remarks
/// You must `free()` the returned buffer once you are done with it.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn compileSpirvFromHlsl(
    info: HlslInfo,
) ![]u8 {
    const info_sdl = info.toSdl();
    var size: usize = undefined;
    return @as([*]u8, @ptrCast(try errors.wrapCallNull(*anyopaque, c.SDL_ShaderCross_CompileSPIRVFromHLSL(&info_sdl, &size))))[0..@intCast(size)];
}

/// De-initialize SDL shadercross.
///
/// ## Thread Safety
/// This should only be called once, from a single thread.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn deinit() void {
    c.SDL_ShaderCross_Quit();
}

/// Get the supported shader formats that HLSL cross-compilation can output
///
/// ## Return Value
/// GPU shader fromats supported by HLSL cross-compilation.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
pub fn getHlslShaderFormats() ?gpu.ShaderFormatFlags {
    return gpu.ShaderFormatFlags.fromSdl(c.SDL_ShaderCross_GetHLSLShaderFormats());
}

/// Get the supported shader formats that SPIRV cross-compilation can output.
///
/// ## Return Value
/// GPU shader fromats supported by SPIRV cross-compilation.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
pub fn getSpirvShaderFormats() ?gpu.ShaderFormatFlags {
    return gpu.ShaderFormatFlags.fromSdl(c.SDL_ShaderCross_GetSPIRVShaderFormats());
}

/// Initialize SDL shadercross.
///
/// ## Thread Safety
/// This should only be called once, from a single thread.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn init() !void {
    return errors.wrapCallBool(c.SDL_ShaderCross_Init());
}

/// Reflect compute pipeline info from SPIRV code.
///
/// ## Function Parameters
/// * `bytecode`: The SPIRV bytecode.
///
/// ## Return Value
/// Returns the metadata.
///
/// ## Remarks
/// If your shader source is HLSL, you should obtain SPIR-V bytecode from `compileSpirvFromHlsl()`.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn reflectComputeSpirv(
    bytecode: []const u8,
) !ComputePipelineMetadata {
    const ret = try errors.wrapCallNull(*c.SDL_ShaderCross_ComputePipelineMetadata, c.SDL_ShaderCross_ReflectComputeSPIRV(bytecode.ptr, bytecode.len, 0));
    defer c.SDL_free(ret);
    return @as(*ComputePipelineMetadata, @ptrCast(ret)).*;
}

/// Reflect graphics shader info from SPIRV code.
///
/// ## Function Parameters
/// * `bytecode`: The SPIRV bytecode.
///
/// ## Return Value
/// Returns the graphics shader metadata.
///
/// ## Remarks
/// If your shader source is HLSL, you should obtain SPIR-V bytecode from `compileSpirvFromHlsl()`.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn reflectGraphicsSpirv(
    bytecode: []const u8,
) !GraphicsShaderMetadata {
    const ret = try errors.wrapCallNull(*c.SDL_ShaderCross_GraphicsShaderMetadata, c.SDL_ShaderCross_ReflectGraphicsSPIRV(bytecode.ptr, bytecode.len, 0));
    defer c.SDL_free(ret);
    return GraphicsShaderMetadata.fromSdl(ret.*);
}

/// Transpile to MSL code from SPIRV code.
///
/// ## Function Parameters
/// * `info`: The shader to transpile.
///
/// ## Return Value
/// Returns the MSL source.
/// This needs to be freed with `free()`.
///
/// ## Remarks
/// You must `free()` the returned string once you are done with it.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn transpileMslFromSpirv(
    info: SpirvInfo,
) ![:0]u8 {
    const info_sdl = info.toSdl();
    return std.mem.span(@as([*:0]u8, @ptrCast(try errors.wrapCallNull(*anyopaque, c.SDL_ShaderCross_TranspileMSLFromSPIRV(&info_sdl)))));
}

/// Transpile to HLSL code from SPIRV code.
///
/// ## Function Parameters
/// * `info`: The shader to transpile.
///
/// ## Return Value
/// Returns the HLSL source.
/// This needs to be freed with `free()`.
///
/// ## Remarks
/// You must `free()` the returned string once you are done with it.
///
/// ## Version
/// This function is provided by SDL3 shadercross.
pub fn transpileHlslFromSpirv(
    info: SpirvInfo,
) ![:0]u8 {
    const info_sdl = info.toSdl();
    return std.mem.span(@as([*:0]u8, @ptrCast(try errors.wrapCallNull(*anyopaque, c.SDL_ShaderCross_TranspileHLSLFromSPIRV(&info_sdl)))));
}

// Shadercross testing.
test "Shadercross" {
    std.testing.refAllDeclsRecursive(@This());
}
