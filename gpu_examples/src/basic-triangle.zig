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

const vert_shader_source = @embedFile("rawTriangle.vert");
const vert_shader_name = "Raw Triangle";
const frag_shader_source = @embedFile("solidColor.frag");
const frag_shader_name = "Solid Color";

const window_width = 640;
const window_height = 480;
const small_viewport = sdl3.gpu.Viewport{
    .region = .{ .x = 100, .y = 120, .w = 320, .h = 240 },
    .min_depth = 0.1,
    .max_depth = 1.0,
};
const scissor_rect = sdl3.rect.IRect{ .x = 100, .y = 120, .w = 320, .h = 240 };

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    fill_pipeline: sdl3.gpu.GraphicsPipeline,
    line_pipeline: sdl3.gpu.GraphicsPipeline,
    use_wireframe_mode: bool = false,
    use_small_viewport: bool = false,
    use_scissor_rect: bool = false,
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
    // const spirv_metadata = try sdl3.shadercross.reflectGraphicsSpirv(spirv_code);
    return try sdl3.shadercross.compileGraphicsShaderFromSpirv(device, .{
        .bytecode = spirv_code,
        .enable_debug = options.gpu_debug,
        .entry_point = "main",
        .name = name,
        .shader_stage = stage,
    }, .{
        .inputs = &.{},
        .outputs = &.{},
        .num_samplers = 0,
        .num_storage_buffers = 0,
        .num_storage_textures = 0,
        .num_uniform_buffers = 0,
    });
}

pub fn init(
    app_state: *?*AppState,
    args: [][*:0]u8,
) !sdl3.AppResult {
    _ = args;

    try sdl3.init(.{ .video = true });

    // Get our GPU device that supports SPIR-V.
    const shader_formats = sdl3.shadercross.getSpirvShaderFormats() orelse @panic("No formats available");
    const device = try sdl3.gpu.Device.init(shader_formats, options.gpu_debug, null);
    errdefer device.deinit();

    // Make our demo window.
    const window = try sdl3.video.Window.init("Basic Triangle", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Prepare pipelines.
    const vertex_shader = loadGraphicsShader(device, vert_shader_name, vert_shader_source, .vertex) catch {
        sdl3.log.log("{s}", .{sdl3.errors.get().?}) catch {};
        @panic(":<");
    };
    defer device.releaseShader(vertex_shader);
    const fragment_shader = try loadGraphicsShader(device, frag_shader_name, frag_shader_source, .fragment);
    defer device.releaseShader(fragment_shader);
    var pipeline_create_info = sdl3.gpu.GraphicsPipelineCreateInfo{
        .target_info = .{
            .color_target_descriptions = &.{
                .{
                    .format = device.getSwapchainTextureFormat(window),
                },
            },
        },
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
    };
    const fill_pipeline = try device.createGraphicsPipeline(pipeline_create_info);
    pipeline_create_info.rasterizer_state.fill_mode = .line;
    const line_pipeline = try device.createGraphicsPipeline(pipeline_create_info);

    // Prepare app state.
    const state = try allocator.create(AppState);
    errdefer allocator.destroy(state);
    state.* = .{
        .device = device,
        .window = window,
        .line_pipeline = line_pipeline,
        .fill_pipeline = fill_pipeline,
    };

    // Generate swapchain for window.
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
        render_pass.bindGraphicsPipeline(if (app_state.use_wireframe_mode) app_state.line_pipeline else app_state.fill_pipeline);
        if (app_state.use_small_viewport)
            render_pass.setViewport(small_viewport);
        if (app_state.use_scissor_rect)
            render_pass.setScissor(scissor_rect);
        render_pass.drawPrimitives(3, 1, 0, 0);
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
        val.device.releaseGraphicsPipeline(val.fill_pipeline);
        val.device.releaseGraphicsPipeline(val.line_pipeline);
        val.device.deinit();
        val.window.deinit();
        allocator.destroy(val);
    }
}
