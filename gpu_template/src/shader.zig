const sdl3 = @import("sdl3");

/// Shader code.
code: []const u8,
/// The format of the shader code.
format: sdl3.gpu.ShaderFormatFlags,
/// The stage the shader program corresponds to.
stage: sdl3.gpu.ShaderStage,
/// The number of samplers defined in the shader.
num_samplers: u32 = 0,
/// The number of storage textures defined in the shader.
num_storage_textures: u32 = 0,
/// The number of storage buffers defined in the shader.
num_storage_buffers: u32 = 0,
/// The number of uniform buffers defined in the shader.
num_uniform_buffers: u32 = 0,
