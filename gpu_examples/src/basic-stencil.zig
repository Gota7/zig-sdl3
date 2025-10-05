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

const vert_shader_source = @embedFile("positionColor.vert");
const vert_shader_name = "Position Color";
const frag_shader_source = @embedFile("solidColor.frag");
const frag_shader_name = "Solid Color";

const window_width = 640;
const window_height = 480;

const PositionColorVertex = packed struct {
    position: @Vector(3, f32),
    color: @Vector(4, u8),
};

const vertices = [_]PositionColorVertex{
    .{ .position = .{ -0.5, -0.5, 0 }, .color = .{ 255, 255, 0, 255 } },
    .{ .position = .{ 0.5, -0.5, 0 }, .color = .{ 255, 255, 0, 255 } },
    .{ .position = .{ 0, 0.5, 0 }, .color = .{ 255, 255, 0, 255 } },
    .{ .position = .{ -1, -1, 0 }, .color = .{ 255, 0, 0, 255 } },
    .{ .position = .{ 1, -1, 0 }, .color = .{ 0, 255, 0, 255 } },
    .{ .position = .{ 0, 1, 0 }, .color = .{ 0, 0, 255, 255 } },
};
const vertices_bytes = std.mem.asBytes(&vertices);

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    masker_pipeline: sdl3.gpu.GraphicsPipeline,
    maskee_pipeline: sdl3.gpu.GraphicsPipeline,
    vertex_buffer: sdl3.gpu.Buffer,
    depth_stencil_texture: sdl3.gpu.Texture,
};

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
    const window = try sdl3.video.Window.init("Basic Stencil", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Get format for the depth stencil.
    const depth_stencil_format: sdl3.gpu.TextureFormat = if (device.textureSupportsFormat(.depth24_unorm_s8_uint, .two_dimensional, .{ .depth_stencil_target = true }))
        .depth24_unorm_s8_uint
    else if (device.textureSupportsFormat(.depth32_float_s8_uint, .two_dimensional, .{ .depth_stencil_target = true }))
        .depth32_float_s8_uint
    else {
        try sdl3.errors.set("Stencil formats not supported");
        unreachable;
    };

    // Prepare pipelines.
    const vertex_shader = try loadGraphicsShader(device, vert_shader_name, vert_shader_source, .vertex);
    defer device.releaseShader(vertex_shader);
    const fragment_shader = try loadGraphicsShader(device, frag_shader_name, frag_shader_source, .fragment);
    defer device.releaseShader(fragment_shader);
    var pipeline_create_info = sdl3.gpu.GraphicsPipelineCreateInfo{
        .target_info = .{
            .color_target_descriptions = &.{
                .{
                    .format = try device.getSwapchainTextureFormat(window),
                },
            },
            .depth_stencil_format = depth_stencil_format,
        },
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
        .vertex_input_state = .{
            .vertex_buffer_descriptions = &.{
                .{
                    .slot = 0,
                    .pitch = @sizeOf(PositionColorVertex),
                    .input_rate = .vertex,
                },
            },
            .vertex_attributes = &.{
                .{
                    .location = 0,
                    .buffer_slot = 0,
                    .format = .f32x3,
                    .offset = @offsetOf(PositionColorVertex, "position"),
                },
                .{
                    .location = 1,
                    .buffer_slot = 0,
                    .format = .u8x4_normalized,
                    .offset = @offsetOf(PositionColorVertex, "color"),
                },
            },
        },
        .depth_stencil_state = .{
            .enable_stencil_test = true,
            .front_stencil_state = .{
                .compare = .never,
                .fail = .replace,
                .pass = .keep,
                .depth_fail = .keep,
            },
            .back_stencil_state = .{
                .compare = .never,
                .fail = .replace,
                .pass = .keep,
                .depth_fail = .keep,
            },
            .write_mask = 0xff,
        },
        .rasterizer_state = .{
            .cull_mode = .none,
            .fill_mode = .fill,
            .front_face = .counter_clockwise,
        },
    };
    const masker_pipeline = try device.createGraphicsPipeline(pipeline_create_info);
    errdefer device.releaseGraphicsPipeline(masker_pipeline);

    // Setup maskee state.
    pipeline_create_info.depth_stencil_state = .{
        .enable_stencil_test = true,
        .front_stencil_state = .{
            .compare = .equal,
            .fail = .keep,
            .pass = .keep,
            .depth_fail = .keep,
        },
        .back_stencil_state = .{
            .compare = .never,
            .fail = .keep,
            .pass = .keep,
            .depth_fail = .keep,
        },
        .compare_mask = 0xff,
        .write_mask = 0,
    };
    const maskee_pipeline = try device.createGraphicsPipeline(pipeline_create_info);
    errdefer device.releaseGraphicsPipeline(maskee_pipeline);

    // Create depth stencil texture.
    const window_size = try window.getSizeInPixels();
    const depth_stencil_texture = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .width = @intCast(window_size.width),
        .height = @intCast(window_size.height),
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .sample_count = .no_multisampling,
        .format = depth_stencil_format,
        .usage = .{ .depth_stencil_target = true },
    });
    errdefer device.releaseTexture(depth_stencil_texture);

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
    try cmd_buf.submit();

    // Prepare app state.
    const state = try allocator.create(AppState);
    errdefer allocator.destroy(state);
    state.* = .{
        .device = device,
        .window = window,
        .masker_pipeline = masker_pipeline,
        .maskee_pipeline = maskee_pipeline,
        .vertex_buffer = vertex_buffer,
        .depth_stencil_texture = depth_stencil_texture,
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
        const render_pass = cmd_buf.beginRenderPass(
            &.{
                sdl3.gpu.ColorTargetInfo{
                    .texture = texture,
                    .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
                    .load = .clear,
                },
            },
            .{
                .texture = app_state.depth_stencil_texture,
                .clear_depth = 0,
                .clear_stencil = 0,
                .load = .clear,
                .store = .do_not_care,
                .stencil_load = .clear,
                .stencil_store = .store,
                .cycle = false,
            },
        );
        defer render_pass.end();
        render_pass.bindVertexBuffers(
            0,
            &.{
                .{ .buffer = app_state.vertex_buffer, .offset = 0 },
            },
        );

        // Draw masker primitives.
        render_pass.setStencilReference(1);
        render_pass.bindGraphicsPipeline(app_state.masker_pipeline);
        render_pass.drawPrimitives(3, 1, 0, 0);

        // Draw maskee primitives.
        render_pass.setStencilReference(0);
        render_pass.bindGraphicsPipeline(app_state.maskee_pipeline);
        render_pass.drawPrimitives(3, 1, 3, 0);
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
        val.device.releaseTexture(val.depth_stencil_texture);
        val.device.releaseBuffer(val.vertex_buffer);
        val.device.releaseGraphicsPipeline(val.masker_pipeline);
        val.device.releaseGraphicsPipeline(val.maskee_pipeline);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
