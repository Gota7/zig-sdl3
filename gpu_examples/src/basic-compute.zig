const options = @import("options");
const sdl3 = @import("sdl3");
const std = @import("std");

comptime {
    _ = sdl3.main_callbacks;
}

// Disable main hack.
pub const _start = void;
pub const WinMainCRTStartup = void;

/// Allocator we will use.
const allocator = std.heap.smp_allocator;

const comp_shader_source = @embedFile("fillTexture.comp");
const comp_shader_name = "Fill Texture";
const vert_shader_source = @embedFile("texturedQuad.vert");
const vert_shader_name = "Textured Quad";
const frag_shader_source = @embedFile("texturedQuad.frag");
const frag_shader_name = "Textured Quad";

const window_width = 640;
const window_height = 480;

const PositionTextureVertex = packed struct {
    position: @Vector(3, f32),
    tex_coord: @Vector(2, f32),
};

const vertices = [_]PositionTextureVertex{
    .{ .position = .{ -1, -1, 0 }, .tex_coord = .{ 0, 0 } },
    .{ .position = .{ 1, -1, 0 }, .tex_coord = .{ 1, 0 } },
    .{ .position = .{ 1, 1, 0 }, .tex_coord = .{ 1, 1 } },
    .{ .position = .{ -1, -1, 0 }, .tex_coord = .{ 0, 0 } },
    .{ .position = .{ 1, 1, 0 }, .tex_coord = .{ 1, 1 } },
    .{ .position = .{ -1, 1, 0 }, .tex_coord = .{ 0, 1 } },
};
const vertices_bytes = std.mem.asBytes(&vertices);

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    draw_pipeline: sdl3.gpu.GraphicsPipeline,
    vertex_buffer: sdl3.gpu.Buffer,
    texture: sdl3.gpu.Texture,
    sampler: sdl3.gpu.Sampler,
};

fn loadComputeShader(
    device: sdl3.gpu.Device,
    name: ?[:0]const u8,
    shader_code: [:0]const u8,
) !struct { pipeline: sdl3.gpu.ComputePipeline, metadata: sdl3.shadercross.ComputePipelineMetadata } {
    const spirv_code = if (options.spirv) shader_code else try sdl3.shadercross.compileSpirvFromHlsl(.{
        .defines = null,
        .enable_debug = options.gpu_debug,
        .entry_point = "main",
        .include_dir = null,
        .name = name,
        .shader_stage = .compute,
        .source = shader_code,
    });
    const spirv_metadata = try sdl3.shadercross.reflectComputeSpirv(spirv_code);
    return .{ .pipeline = try sdl3.shadercross.compileComputePipelineFromSpirv(device, .{
        .bytecode = spirv_code,
        .enable_debug = options.gpu_debug,
        .entry_point = "main",
        .name = name,
        .shader_stage = .compute,
    }, spirv_metadata), .metadata = spirv_metadata };
}

fn loadGraphicsShader(
    device: sdl3.gpu.Device,
    name: ?[:0]const u8,
    shader_code: [:0]const u8,
    stage: sdl3.shadercross.ShaderStage,
) !sdl3.gpu.Shader {
    const spirv_code = if (options.spirv) shader_code else try sdl3.shadercross.compileSpirvFromHlsl(.{
        .defines = null,
        .enable_debug = options.gpu_debug,
        .entry_point = "main",
        .include_dir = null,
        .name = name,
        .shader_stage = stage,
        .source = shader_code,
    });
    const spirv_metadata = try sdl3.shadercross.reflectGraphicsSpirv(spirv_code);
    return try sdl3.shadercross.compileGraphicsShaderFromSpirv(device, .{
        .bytecode = spirv_code,
        .enable_debug = options.gpu_debug,
        .entry_point = "main",
        .name = name,
        .shader_stage = stage,
    }, spirv_metadata);
}

pub fn init(
    app_state: *?*AppState,
    args: [][*:0]u8,
) !sdl3.AppResult {
    _ = args;

    // SDL3 setup.
    try sdl3.init(.{ .video = true });
    sdl3.errors.error_callback = &sdl3.extras.sdlErrZigLog;
    sdl3.log.setLogOutputFunction(void, &sdl3.extras.sdlLogZigLog, null);

    // Get our GPU device that supports SPIR-V.
    const shader_formats = sdl3.shadercross.getSpirvShaderFormats() orelse @panic("No formats available");
    const device = try sdl3.gpu.Device.init(shader_formats, options.gpu_debug, null);
    errdefer device.deinit();

    // Make our demo window.
    const window = try sdl3.video.Window.init("Basic Compute", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Prepare pipelines.
    const vertex_shader = try loadGraphicsShader(device, vert_shader_name, vert_shader_source, .vertex);
    defer device.releaseShader(vertex_shader);
    const fragment_shader = try loadGraphicsShader(device, frag_shader_name, frag_shader_source, .fragment);
    defer device.releaseShader(fragment_shader);
    const pipeline_create_info = sdl3.gpu.GraphicsPipelineCreateInfo{
        .target_info = .{
            .color_target_descriptions = &.{
                .{
                    .format = try device.getSwapchainTextureFormat(window),
                },
            },
        },
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
        .vertex_input_state = .{
            .vertex_buffer_descriptions = &.{
                .{
                    .slot = 0,
                    .pitch = @sizeOf(PositionTextureVertex),
                    .input_rate = .vertex,
                },
            },
            .vertex_attributes = &.{
                .{
                    .location = 0,
                    .buffer_slot = 0,
                    .format = .f32x3,
                    .offset = @offsetOf(PositionTextureVertex, "position"),
                },
                .{
                    .location = 1,
                    .buffer_slot = 0,
                    .format = .f32x2,
                    .offset = @offsetOf(PositionTextureVertex, "tex_coord"),
                },
            },
        },
    };
    const draw_pipeline = try device.createGraphicsPipeline(pipeline_create_info);
    errdefer device.releaseGraphicsPipeline(draw_pipeline);

    // Prepare texture and sampler.
    const texture = try device.createTexture(.{
        .format = .r8g8b8a8_unorm,
        .width = window_width,
        .height = window_height,
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = .{ .compute_storage_write = true, .sampler = true },
    });
    errdefer device.releaseTexture(texture);
    const sampler = try device.createSampler(.{
        .address_mode_u = .repeat,
        .address_mode_v = .repeat,
    });
    errdefer device.releaseSampler(sampler);

    // Prepare vertex buffer.
    const vertex_buffer = try device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = vertices_bytes.len,
    });
    errdefer device.releaseBuffer(vertex_buffer);

    // Setup transfer buffer.
    const transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = vertices_bytes.len,
    });
    defer device.releaseTransferBuffer(transfer_buffer);
    {
        const transfer_buffer_mapped = try device.mapTransferBuffer(transfer_buffer, false);
        defer device.unmapTransferBuffer(transfer_buffer);
        @memcpy(transfer_buffer_mapped, vertices_bytes);
    }

    // Create compute pipeline.
    const fill_texture_pipeline_result = try loadComputeShader(device, comp_shader_name, comp_shader_source);
    defer device.releaseComputePipeline(fill_texture_pipeline_result.pipeline);

    // Upload transfer data.
    const cmd_buf = try device.acquireCommandBuffer();
    {
        const copy_pass = cmd_buf.beginCopyPass();
        defer copy_pass.end();
        copy_pass.uploadToBuffer(
            .{
                .transfer_buffer = transfer_buffer,
                .offset = 0,
            },
            .{
                .buffer = vertex_buffer,
                .offset = 0,
                .size = vertices_bytes.len,
            },
            false,
        );
    }

    // Create fill texture.
    {
        const compute_pass = cmd_buf.beginComputePass(&.{
            .{ .texture = texture },
        }, &.{});
        defer compute_pass.end();
        compute_pass.bindPipeline(fill_texture_pipeline_result.pipeline);
        compute_pass.dispatch(window_width / fill_texture_pipeline_result.metadata.threadcount_x, window_height / fill_texture_pipeline_result.metadata.threadcount_y, fill_texture_pipeline_result.metadata.threadcount_z);
    }
    try cmd_buf.submit();

    // Prepare app state.
    const state = try allocator.create(AppState);
    errdefer allocator.destroy(state);
    state.* = .{
        .device = device,
        .window = window,
        .draw_pipeline = draw_pipeline,
        .vertex_buffer = vertex_buffer,
        .texture = texture,
        .sampler = sampler,
    };

    // Finish setup.
    app_state.* = state;
    return .run;
}

pub fn iterate(
    app_state: *AppState,
) !sdl3.AppResult {

    // Get command buffer and swapchain texture.
    const cmd_buf = try app_state.device.acquireCommandBuffer();
    const swapchain_texture = try cmd_buf.waitAndAcquireSwapchainTexture(app_state.window);
    if (swapchain_texture.texture) |texture| {

        // Start a render pass if the swapchain texture is available. Make sure to clear it.
        const render_pass = cmd_buf.beginRenderPass(&.{
            sdl3.gpu.ColorTargetInfo{
                .texture = texture,
                .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
                .load = .clear,
            },
        }, null);
        defer render_pass.end();
        render_pass.bindGraphicsPipeline(app_state.draw_pipeline);
        render_pass.bindVertexBuffers(
            0,
            &.{
                .{ .buffer = app_state.vertex_buffer, .offset = 0 },
            },
        );
        render_pass.bindFragmentSamplers(
            0,
            &.{
                .{ .texture = app_state.texture, .sampler = app_state.sampler },
            },
        );
        render_pass.drawPrimitives(6, 1, 0, 0);
    }

    // Finally submit the command buffer.
    try cmd_buf.submit();

    return .run;
}

pub fn event(
    app_state: *AppState,
    curr_event: sdl3.events.Event,
) !sdl3.AppResult {
    _ = app_state;
    switch (curr_event) {
        .terminating => return .success,
        .quit => return .success,
        else => {},
    }
    return .run;
}

pub fn quit(
    app_state: ?*AppState,
    result: sdl3.AppResult,
) void {
    _ = result;
    if (app_state) |val| {
        val.device.releaseSampler(val.sampler);
        val.device.releaseTexture(val.texture);
        val.device.releaseBuffer(val.vertex_buffer);
        val.device.releaseGraphicsPipeline(val.draw_pipeline);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
