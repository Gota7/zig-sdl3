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

const AppState = struct {
    device: sdl3.gpu.Device,
    window1: sdl3.video.Window,
    window2: sdl3.video.Window,
};

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

    // Make our demo windows.
    const window1 = try sdl3.video.Window.init("Window 1", 640, 480, .{});
    errdefer window1.deinit();
    const window2 = try sdl3.video.Window.init("Window 2", 640, 480, .{});
    errdefer window2.deinit();

    // Prepare app state.
    const state = try allocator.create(AppState);
    errdefer allocator.destroy(state);
    state.* = .{
        .device = device,
        .window1 = window1,
        .window2 = window2,
    };

    // Generate swapchain for window.
    try device.claimWindow(window1);
    try device.claimWindow(window2);
    app_state.* = state;
    try sdl3.log.log("Press the escape key to quit", .{});
    return .run;
}

pub fn iterate(
    app_state: *AppState,
) !sdl3.AppResult {

    // Get command buffer and swapchain texture.
    const cmd_buf = try app_state.device.acquireCommandBuffer();
    const swapchain_texture1 = try cmd_buf.waitAndAcquireSwapchainTexture(app_state.window1);
    if (swapchain_texture1.texture) |texture| {

        // Start a render pass if the swapchain texture is available. Make sure to clear it.
        const render_pass = cmd_buf.beginRenderPass(&.{
            sdl3.gpu.ColorTargetInfo{
                .texture = texture,
                .clear_color = .{ .r = 0.3, .g = 0.4, .b = 0.5, .a = 1 },
                .load = .clear,
            },
        }, null);
        defer render_pass.end();
    }
    const swapchain_texture2 = try cmd_buf.waitAndAcquireSwapchainTexture(app_state.window2);
    if (swapchain_texture2.texture) |texture| {

        // Start a render pass if the swapchain texture is available. Make sure to clear it.
        const render_pass = cmd_buf.beginRenderPass(&.{
            sdl3.gpu.ColorTargetInfo{
                .texture = texture,
                .clear_color = .{ .r = 1, .g = 0.5, .b = 0.6, .a = 1 },
                .load = .clear,
            },
        }, null);
        defer render_pass.end();
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
        .key_down => |key| return if (key.key == .escape) .success else .run,
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
        val.device.deinit();
        val.window1.deinit();
        val.window2.deinit();
        allocator.destroy(val);
    }
}
