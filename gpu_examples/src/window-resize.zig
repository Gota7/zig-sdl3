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

const resolutions = [_]@Vector(2, u32){
    .{ 640, 480 },
    .{ 1280, 720 },
    .{ 1024, 1024 },
    .{ 1600, 900 },
    .{ 1920, 1080 },
    .{ 3200, 1800 },
    .{ 3840, 2160 },
};

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    pipeline: sdl3.gpu.GraphicsPipeline,
    resolution_index: usize = 0,
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
    const window = try sdl3.video.Window.init("Window Resize", resolutions[0][0], resolutions[0][1], .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Prepare pipelines.
    const vertex_shader = try loadGraphicsShader(device, vert_shader_name, vert_shader_source, .vertex);
    defer device.releaseShader(vertex_shader);
    const fragment_shader = try loadGraphicsShader(device, frag_shader_name, frag_shader_source, .fragment);
    defer device.releaseShader(fragment_shader);
    const pipeline = try device.createGraphicsPipeline(.{
        .target_info = .{
            .color_target_descriptions = &.{
                .{
                    .format = try device.getSwapchainTextureFormat(window),
                },
            },
        },
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
    });
    errdefer device.releaseGraphicsPipeline(pipeline);

    // Prepare app state.
    const state = try allocator.create(AppState);
    errdefer allocator.destroy(state);
    state.* = .{
        .device = device,
        .window = window,
        .pipeline = pipeline,
    };

    // Finish setup.
    app_state.* = state;
    try sdl3.log.log("Press left/right to resize the window", .{});
    try sdl3.log.log(
        "Resolution: {d}x{d}",
        .{ resolutions[state.resolution_index][0], resolutions[state.resolution_index][1] },
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
        const render_pass = cmd_buf.beginRenderPass(&.{
            sdl3.gpu.ColorTargetInfo{
                .texture = texture,
                .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
                .load = .clear,
            },
        }, null);
        defer render_pass.end();
        render_pass.bindGraphicsPipeline(app_state.pipeline);
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
    switch (curr_event) {
        .key_down => |key| {
            if (!key.repeat) {
                var changed = false;
                if (key.key) |val| switch (val) {
                    .left => {
                        if (app_state.resolution_index == 0) {
                            app_state.resolution_index = resolutions.len - 1;
                        } else app_state.resolution_index -= 1;
                        changed = true;
                    },
                    .right => {
                        if (app_state.resolution_index >= resolutions.len - 1) {
                            app_state.resolution_index = 0;
                        } else app_state.resolution_index += 1;
                        changed = true;
                    },
                    else => {},
                };
                if (changed) {
                    try app_state.window.setSize(resolutions[app_state.resolution_index][0], resolutions[app_state.resolution_index][1]);
                    try app_state.window.setPosition(.{ .centered = null }, .{ .centered = null });
                    try app_state.window.sync();
                    try sdl3.log.log(
                        "Resolution: {d}x{d}",
                        .{ resolutions[app_state.resolution_index][0], resolutions[app_state.resolution_index][1] },
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
        val.device.releaseGraphicsPipeline(val.pipeline);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
