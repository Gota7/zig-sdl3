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

const target_width = 64;
const target_height = 64;

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    texture_3d: sdl3.gpu.Texture,
};

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
    const window = try sdl3.video.Window.init("Clear 3d Slice", 640, 480, .{ .resizable = true });
    errdefer window.deinit();
    try device.claimWindow(window);

    // Prepare texture.
    const texture_3d = try device.createTexture(.{
        .texture_type = .three_dimensional,
        .format = try device.getSwapchainTextureFormat(window),
        .width = target_width,
        .height = target_height,
        .layer_count_or_depth = 4,
        .num_levels = 1,
        .usage = .{ .color_target = true, .sampler = true },
    });
    errdefer device.releaseTexture(texture_3d);

    // Prepare app state.
    const state = try allocator.create(AppState);
    errdefer allocator.destroy(state);
    state.* = .{
        .device = device,
        .window = window,
        .texture_3d = texture_3d,
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
        const render_pass1 = cmd_buf.beginRenderPass(&.{
            sdl3.gpu.ColorTargetInfo{
                .texture = app_state.texture_3d,
                .clear_color = .{ .r = 1, .g = 0, .b = 0, .a = 1 },
                .load = .clear,
                .cycle = true,
                .layer_or_depth_plane = 0,
            },
        }, null);
        render_pass1.end();
        const render_pass2 = cmd_buf.beginRenderPass(&.{
            sdl3.gpu.ColorTargetInfo{
                .texture = app_state.texture_3d,
                .clear_color = .{ .r = 0, .g = 1, .b = 0, .a = 1 },
                .load = .clear,
                .cycle = false,
                .layer_or_depth_plane = 1,
            },
        }, null);
        render_pass2.end();
        const render_pass3 = cmd_buf.beginRenderPass(&.{
            sdl3.gpu.ColorTargetInfo{
                .texture = app_state.texture_3d,
                .clear_color = .{ .r = 0, .g = 0, .b = 1, .a = 1 },
                .load = .clear,
                .cycle = false,
                .layer_or_depth_plane = 2,
            },
        }, null);
        render_pass3.end();
        const render_pass4 = cmd_buf.beginRenderPass(&.{
            sdl3.gpu.ColorTargetInfo{
                .texture = app_state.texture_3d,
                .clear_color = .{ .r = 1, .g = 0, .b = 1, .a = 1 },
                .load = .clear,
                .cycle = false,
                .layer_or_depth_plane = 3,
            },
        }, null);
        render_pass4.end();

        for (0..4) |i| {
            const dst_x = (i % 2) * (swapchain_texture.width / 2);
            const dst_y = if (i > 1) swapchain_texture.height / 2 else 0;
            cmd_buf.blitTexture(.{
                .source = .{
                    .texture = app_state.texture_3d,
                    .layer_or_depth_plane = @intCast(i),
                    .region = .{ .x = 0, .y = 0, .w = target_width, .h = target_height },
                },
                .destination = .{
                    .texture = texture,
                    .region = .{ .x = @intCast(dst_x), .y = @intCast(dst_y), .w = swapchain_texture.width / 2, .h = swapchain_texture.height / 2 },
                },
                .load_op = .load,
                .filter = .nearest,
                .flip_mode = .{},
            });
        }
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
        val.device.releaseTexture(val.texture_3d);
        val.device.deinit();
        val.window.deinit();
        allocator.destroy(val);
    }
}
