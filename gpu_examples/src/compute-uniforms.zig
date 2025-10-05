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

const comp_shader_source = @embedFile("gradientTexture.comp");
const comp_shader_name = "Gradient Texture";

const window_width = 640;
const window_height = 480;

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    gradient_render_texture: sdl3.gpu.Texture,
    gradient_render_pipeline: sdl3.gpu.ComputePipeline,
    gradient_render_pipeline_metadata: sdl3.shadercross.ComputePipelineMetadata,
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
    const window = try sdl3.video.Window.init("Compute Uniforms", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Create compute pipeline.
    const gradient_texture_pipeline_result = try loadComputeShader(device, comp_shader_name, comp_shader_source);
    errdefer device.releaseComputePipeline(gradient_texture_pipeline_result.pipeline);

    // Prepare texture.
    const gradient_render_texture = try device.createTexture(.{
        .format = .r8g8b8a8_unorm,
        .width = window_width,
        .height = window_width,
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = .{ .compute_storage_write = true, .sampler = true },
    });
    errdefer device.releaseTexture(gradient_render_texture);

    // Prepare app state.
    const state = try allocator.create(AppState);
    errdefer allocator.destroy(state);
    state.* = .{
        .device = device,
        .window = window,
        .gradient_render_texture = gradient_render_texture,
        .gradient_render_pipeline = gradient_texture_pipeline_result.pipeline,
        .gradient_render_pipeline_metadata = gradient_texture_pipeline_result.metadata,
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
        {
            const compute_pass = cmd_buf.beginComputePass(
                &.{
                    .{ .texture = app_state.gradient_render_texture, .cycle = true },
                },
                &.{},
            );
            defer compute_pass.end();
            compute_pass.bindPipeline(app_state.gradient_render_pipeline);
            cmd_buf.pushComputeUniformData(0, std.mem.asBytes(&(@as(f32, @floatFromInt(sdl3.timer.getMillisecondsSinceInit())) / 1000)));
            compute_pass.dispatch(
                swapchain_texture.width / app_state.gradient_render_pipeline_metadata.threadcount_x,
                swapchain_texture.height / app_state.gradient_render_pipeline_metadata.threadcount_y,
                app_state.gradient_render_pipeline_metadata.threadcount_z,
            );
        }
        cmd_buf.blitTexture(.{
            .source = .{
                .texture = app_state.gradient_render_texture,
                .region = .{ .x = 0, .y = 0, .w = window_width, .h = window_height },
            },
            .destination = .{
                .texture = texture,
                .region = .{ .x = 0, .y = 0, .w = swapchain_texture.width, .h = swapchain_texture.height },
            },
            .load_op = .do_not_care,
            .filter = .linear,
        });
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
        val.device.releaseComputePipeline(val.gradient_render_pipeline);
        val.device.releaseTexture(val.gradient_render_texture);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
