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

const cube_bmp = @embedFile("images/cube0.bmp");

const window_width = 640;
const window_height = 480;

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    mipmap_texture: sdl3.gpu.Texture,
    texture_width: u32,
    texture_height: u32,
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
    const window = try sdl3.video.Window.init("Generate Mipmaps", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Load the image.
    const image_data = try loadImage(cube_bmp);
    defer image_data.deinit();
    const image_bytes = image_data.getPixels().?[0 .. image_data.getWidth() * image_data.getHeight() * @sizeOf(u8) * 4];

    // Create texture.
    const mipmap_texture = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .format = .r8g8b8a8_unorm,
        .width = @intCast(image_data.getWidth()),
        .height = @intCast(image_data.getHeight()),
        .layer_count_or_depth = 1,
        .num_levels = 3,
        .usage = .{ .sampler = true, .color_target = true },
        .props = .{ .name = "Cube Texture" },
    });
    errdefer device.releaseTexture(mipmap_texture);

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
                .texture = mipmap_texture,
                .width = @intCast(image_data.getWidth()),
                .height = @intCast(image_data.getHeight()),
                .depth = 1,
            },
            false,
        );
    }
    cmd_buf.generateMipmapsForTexture(mipmap_texture);
    try cmd_buf.submit();

    // Prepare app state.
    const state = try allocator.create(AppState);
    errdefer allocator.destroy(state);
    state.* = .{
        .device = device,
        .window = window,
        .mipmap_texture = mipmap_texture,
        .texture_width = @intCast(image_data.getWidth()),
        .texture_height = @intCast(image_data.getHeight()),
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
        {
            const render_pass = cmd_buf.beginRenderPass(&.{
                sdl3.gpu.ColorTargetInfo{
                    .texture = texture,
                    .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
                    .load = .clear,
                },
            }, null);
            defer render_pass.end();
        }

        // Blit the smallest mip level.
        cmd_buf.blitTexture(.{
            .source = .{
                .texture = app_state.mipmap_texture,
                .region = .{ .x = 0, .y = 0, .w = app_state.texture_width / 4, .h = app_state.texture_height / 4 },
                .mip_level = 2,
            },
            .destination = .{
                .texture = texture,
                .region = .{ .x = 0, .y = 0, .w = swapchain_texture.width, .h = swapchain_texture.height },
            },
            .load_op = .do_not_care,
            .filter = .nearest,
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
        val.device.releaseTexture(val.mipmap_texture);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
