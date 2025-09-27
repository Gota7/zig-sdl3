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
const scissor_rect = sdl3.rect.IRect{ .x = 320, .y = 240, .w = 320, .h = 240 };

const max_num_samples = 4;

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    pipelines: [max_num_samples]sdl3.gpu.GraphicsPipeline,
    msaaRenderTextures: [max_num_samples]sdl3.gpu.Texture,
    resolve_texture: sdl3.gpu.Texture,
    sample_counts: usize,
    curr_sample_count_ind: usize = 0,
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
    const window = try sdl3.video.Window.init("Triangle MSAA", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Prepare pipelines.
    const vertex_shader = try loadGraphicsShader(device, vert_shader_name, vert_shader_source, .vertex);
    defer device.releaseShader(vertex_shader);
    const fragment_shader = try loadGraphicsShader(device, frag_shader_name, frag_shader_source, .fragment);
    defer device.releaseShader(fragment_shader);
    const swapchain_format = try device.getSwapchainTextureFormat(window);
    var pipeline_create_info = sdl3.gpu.GraphicsPipelineCreateInfo{
        .target_info = .{
            .color_target_descriptions = &.{
                .{
                    .format = swapchain_format,
                },
            },
        },
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
    };
    var pipelines: [max_num_samples]sdl3.gpu.GraphicsPipeline = undefined;
    var textures: [max_num_samples]sdl3.gpu.Texture = undefined;
    var sample_counts: usize = 0;

    // Hacky way to cleanup resources in case of failure.
    const Cb = struct {
        fn cleanup(
            p_device: sdl3.gpu.Device,
            p_pipelines: [max_num_samples]sdl3.gpu.GraphicsPipeline,
            p_textures: [max_num_samples]sdl3.gpu.Texture,
            num_pipelines: usize,
            num_textures: usize,
        ) void {
            for (0..num_pipelines) |ind|
                p_device.releaseGraphicsPipeline(p_pipelines[ind]);

            for (0..num_textures) |ind|
                p_device.releaseTexture(p_textures[ind]);
        }
    };
    for (0..max_num_samples) |num_samples| {
        const sample_count: sdl3.gpu.SampleCount = @enumFromInt(num_samples);
        if (!device.textureSupportsSampleCount(swapchain_format, sample_count))
            continue;
        pipeline_create_info.multisample_state = .{ .sample_count = sample_count };

        pipelines[sample_counts] = device.createGraphicsPipeline(pipeline_create_info) catch {
            Cb.cleanup(device, pipelines, textures, sample_counts, sample_counts);
            return .failure;
        };
        textures[sample_counts] = device.createTexture(.{
            .texture_type = .two_dimensional,
            .width = window_width,
            .height = window_height,
            .layer_count_or_depth = 1,
            .num_levels = 1,
            .format = swapchain_format,
            .usage = .{ .color_target = true, .sampler = sample_count == .no_multisampling },
            .sample_count = sample_count,
        }) catch {
            Cb.cleanup(device, pipelines, textures, sample_counts + 1, sample_counts);
            return .failure;
        };
        sample_counts += 1;
    }
    errdefer Cb.cleanup(device, pipelines, textures, sample_counts, sample_counts);

    // Create resolve texture.
    const resolve_texture = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .width = window_width,
        .height = window_height,
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .format = swapchain_format,
        .usage = .{ .color_target = true, .sampler = true },
    });
    errdefer device.releaseTexture(resolve_texture);

    // Prepare app state.
    const state = try allocator.create(AppState);
    errdefer allocator.destroy(state);
    state.* = .{
        .device = device,
        .window = window,
        .pipelines = pipelines,
        .msaaRenderTextures = textures,
        .resolve_texture = resolve_texture,
        .sample_counts = sample_counts,
    };

    // Finish setup.
    app_state.* = state;
    try sdl3.log.log("Press left/right to cycle between sample counts", .{});
    try sdl3.log.log(
        "Sample Count: {s}",
        .{@tagName(@as(sdl3.gpu.SampleCount, @enumFromInt(state.curr_sample_count_ind)))},
    );
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
        const resolve = @as(sdl3.gpu.SampleCount, @enumFromInt(app_state.curr_sample_count_ind)) != .no_multisampling;
        {
            const render_pass = cmd_buf.beginRenderPass(&.{
                sdl3.gpu.ColorTargetInfo{
                    .texture = app_state.msaaRenderTextures[app_state.curr_sample_count_ind],
                    .clear_color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
                    .load = .clear,
                    .store = if (resolve) .resolve else .store,
                    .resolve_texture = if (resolve) app_state.resolve_texture else .null,
                },
            }, null);
            defer render_pass.end();
            render_pass.bindGraphicsPipeline(app_state.pipelines[app_state.curr_sample_count_ind]);
            render_pass.drawPrimitives(3, 1, 0, 0);
        }
        cmd_buf.blitTexture(.{
            .source = .{
                .texture = if (resolve) app_state.resolve_texture else app_state.msaaRenderTextures[app_state.curr_sample_count_ind],
                .region = .{ .x = window_width / 4, .y = 0, .w = window_width / 2, .h = window_height / 2 },
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
    switch (curr_event) {
        .key_down => |key| {
            if (!key.repeat) {
                var changed = false;
                if (key.key) |val| switch (val) {
                    .left => {
                        if (app_state.curr_sample_count_ind == 0) {
                            app_state.curr_sample_count_ind = app_state.sample_counts - 1;
                        } else app_state.curr_sample_count_ind -= 1;
                        changed = true;
                    },
                    .right => {
                        if (app_state.curr_sample_count_ind >= app_state.sample_counts - 1) {
                            app_state.curr_sample_count_ind = 0;
                        } else app_state.curr_sample_count_ind += 1;
                        changed = true;
                    },
                    else => {},
                };
                if (changed) {
                    try sdl3.log.log(
                        "Sample Count: {s}",
                        .{@tagName(@as(sdl3.gpu.SampleCount, @enumFromInt(app_state.curr_sample_count_ind)))},
                    );
                }
            }
        },
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
        for (0..val.sample_counts) |ind| {
            val.device.releaseGraphicsPipeline(val.pipelines[ind]);
            val.device.releaseTexture(val.msaaRenderTextures[ind]);
        }
        val.device.releaseTexture(val.resolve_texture);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
