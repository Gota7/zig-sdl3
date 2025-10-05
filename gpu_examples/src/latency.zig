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

const latency_bmp = @embedFile("images/latency.bmp");

const window_width = 640;
const window_height = 480;

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    lag_texture: sdl3.gpu.Texture,
    texture_width: u32,
    texture_height: u32,
    lag_x: f32 = 1,
    allows_frames_in_flight: u32 = 2,
    capture_cursor: bool = false,
    fullscreen: bool = false,
};

pub fn loadImage(
    bmp: []const u8,
) !sdl3.surface.Surface {
    const image_data_raw = try sdl3.surface.Surface.initFromBmpIo(try sdl3.io_stream.Stream.initFromConstMem(bmp), true);
    defer image_data_raw.deinit();
    return image_data_raw.convertFormat(sdl3.pixels.Format.packed_abgr_8_8_8_8);
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
    const window = try sdl3.video.Window.init("Latency", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Load the image.
    const image_data = try loadImage(latency_bmp);
    defer image_data.deinit();
    const image_bytes = image_data.getPixels().?[0 .. image_data.getWidth() * image_data.getHeight() * @sizeOf(u8) * 4];

    // Create texture.
    const lag_texture = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .format = .r8g8b8a8_unorm,
        .width = @intCast(image_data.getWidth()),
        .height = @intCast(image_data.getHeight()),
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = .{ .sampler = true },
        .props = .{ .name = "Latency Texture" },
    });
    errdefer device.releaseTexture(lag_texture);

    // Setup transfer buffer.
    const transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = @intCast(image_bytes.len),
    });
    defer device.releaseTransferBuffer(transfer_buffer);
    {
        const transfer_buffer_mapped = try device.mapTransferBuffer(transfer_buffer, false);
        defer device.unmapTransferBuffer(transfer_buffer);
        @memcpy(transfer_buffer_mapped[0..image_bytes.len], image_bytes);
    }

    // Upload transfer data.
    const cmd_buf = try device.acquireCommandBuffer();
    {
        const copy_pass = cmd_buf.beginCopyPass();
        defer copy_pass.end();
        copy_pass.uploadToTexture(
            .{
                .transfer_buffer = transfer_buffer,
                .offset = 0,
            },
            .{
                .texture = lag_texture,
                .width = @intCast(image_data.getWidth()),
                .height = @intCast(image_data.getHeight()),
                .depth = 1,
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
        .lag_texture = lag_texture,
        .texture_width = @intCast(image_data.getWidth()),
        .texture_height = @intCast(image_data.getHeight()),
    };
    try device.setAllowedFramesInFlight(state.allows_frames_in_flight);

    // Finish setup.
    try sdl3.log.log("Press left/right to change the number of allowed frames in flight", .{});
    try sdl3.log.log("Press down to toggle capturing the mouse cursor", .{});
    try sdl3.log.log("Press up to toggle fullscreen mode", .{});
    try sdl3.log.log("When the mouse cursor is captured the color directly above the cursor's point in the result of the test", .{});
    try sdl3.log.log("Negative lag can occur when the cursor is below the tear line when tearing is enabled as the cursor is only moved during V-blank so it lags the framebuffer update", .{});
    try sdl3.log.log("  Gray:  -1 frames lag", .{});
    try sdl3.log.log("  White:  0 frames lag", .{});
    try sdl3.log.log("  Green:  1 frames lag", .{});
    try sdl3.log.log("  Yellow: 2 frames lag", .{});
    try sdl3.log.log("  Red:    3 frames lag", .{});
    try sdl3.log.log("  Cyan:   4 frames lag", .{});
    try sdl3.log.log("  Purple: 5 frames lag", .{});
    try sdl3.log.log("  Blue:   6 frames lag", .{});
    try sdl3.log.log(
        "State: {{CaptureMouseCursor: {any}, AllowedFramesInFlight: {any}, Fullscreen: {any}}}",
        .{ state.capture_cursor, state.allows_frames_in_flight, state.fullscreen },
    );
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
        const cursor = sdl3.mouse.getGlobalState();
        const window_pos = try app_state.window.getPosition();
        var cursorX = cursor.x - @as(f32, @floatFromInt(window_pos.x));
        const cursorY = cursor.y - @as(f32, @floatFromInt(window_pos.y));

        // Move cursor to a known position.
        if (app_state.capture_cursor) {
            cursorX = app_state.lag_x;
            sdl3.mouse.warpInWindow(app_state.window, cursorX, cursorY);
            if (app_state.lag_x >= @as(f32, @floatFromInt(swapchain_texture.width - app_state.texture_width))) {
                app_state.lag_x = 1;
            } else {
                app_state.lag_x += 1;
            }
        }

        // Draw a sprite directly under the cursor if permitted by the blitting engine.
        if (cursorX >= 1 and cursorX <= @as(f32, @floatFromInt(swapchain_texture.width - app_state.texture_width)) and cursorY >= 5 and cursorY <= @as(f32, @floatFromInt(swapchain_texture.height - app_state.texture_height + 5))) {
            cmd_buf.blitTexture(.{
                .source = .{
                    .texture = app_state.lag_texture,
                    .region = .{ .x = 0, .y = 0, .w = app_state.texture_width, .h = app_state.texture_height },
                },
                .destination = .{
                    .texture = texture,
                    .region = .{ .x = @intFromFloat(cursorX - 1), .y = @intFromFloat(cursorY - 5), .w = app_state.texture_width, .h = app_state.texture_height },
                },
                .load_op = .clear,
                .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
                .filter = .nearest,
            });
        } else {
            const render_pass = cmd_buf.beginRenderPass(&.{
                sdl3.gpu.ColorTargetInfo{
                    .texture = texture,
                    .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
                    .load = .clear,
                },
            }, null);
            defer render_pass.end();
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
    switch (curr_event) {
        .key_down => |key| {
            if (!key.repeat) {
                var changed = false;
                if (key.key) |val| switch (val) {
                    .left => {
                        if (app_state.allows_frames_in_flight <= 1) {
                            app_state.allows_frames_in_flight = 3;
                        } else app_state.allows_frames_in_flight -= 1;
                        try app_state.device.setAllowedFramesInFlight(app_state.allows_frames_in_flight);
                        changed = true;
                    },
                    .right => {
                        if (app_state.allows_frames_in_flight >= 3) {
                            app_state.allows_frames_in_flight = 1;
                        } else app_state.allows_frames_in_flight += 1;
                        try app_state.device.setAllowedFramesInFlight(app_state.allows_frames_in_flight);
                        changed = true;
                    },
                    .down => {
                        app_state.capture_cursor = !app_state.capture_cursor;
                        changed = true;
                    },
                    .up => {
                        app_state.fullscreen = !app_state.fullscreen;
                        try app_state.window.setFullscreen(app_state.fullscreen);
                        changed = true;
                    },
                    else => {},
                };
                if (changed) {
                    try sdl3.log.log(
                        "State: {{CaptureMouseCursor: {any}, AllowedFramesInFlight: {any}, Fullscreen: {any}}}",
                        .{ app_state.capture_cursor, app_state.allows_frames_in_flight, app_state.fullscreen },
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
        val.device.releaseTexture(val.lag_texture);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
