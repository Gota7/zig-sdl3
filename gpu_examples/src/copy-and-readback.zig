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

const ravioli_bmp = @embedFile("images/ravioli.bmp");

const buffer_data = [_]u32{
    2,
    4,
    8,
    16,
    32,
    64,
    128,
};
const buffer_data_bytes = std.mem.asBytes(&buffer_data);

const window_width = 640;
const window_height = 480;

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    original_texture: sdl3.gpu.Texture,
    texture_copy: sdl3.gpu.Texture,
    texture_small: sdl3.gpu.Texture,
    original_buffer: sdl3.gpu.Buffer,
    buffer_copy: sdl3.gpu.Buffer,
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
    const window = try sdl3.video.Window.init("Copy And Readback", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Load the image.
    const image_data = try loadImage(ravioli_bmp);
    defer image_data.deinit();
    const image_bytes = image_data.getPixels().?[0 .. image_data.getWidth() * image_data.getHeight() * @sizeOf(u8) * 4];

    // Create textures.
    const original_texture = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .format = .r8g8b8a8_unorm,
        .width = @intCast(image_data.getWidth()),
        .height = @intCast(image_data.getHeight()),
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = .{ .sampler = true },
        .props = .{ .name = "Ravioli Texture" },
    });
    errdefer device.releaseTexture(original_texture);
    const texture_copy = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .format = .r8g8b8a8_unorm,
        .width = @intCast(image_data.getWidth()),
        .height = @intCast(image_data.getHeight()),
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = .{ .sampler = true },
        .props = .{ .name = "Ravioli Texture Copy" },
    });
    errdefer device.releaseTexture(texture_copy);
    const texture_small = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .format = .r8g8b8a8_unorm,
        .width = @intCast(image_data.getWidth() / 2),
        .height = @intCast(image_data.getHeight() / 2),
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = .{ .sampler = true, .color_target = true },
        .props = .{ .name = "Ravioli Texture Small" },
    });
    errdefer device.releaseTexture(texture_small);

    // Create buffers.
    const original_buffer = try device.createBuffer(.{
        .usage = .{ .graphics_storage_read = true },
        .size = buffer_data_bytes.len,
    });
    errdefer device.releaseBuffer(original_buffer);
    const buffer_copy = try device.createBuffer(.{
        .usage = .{ .graphics_storage_read = true },
        .size = buffer_data_bytes.len,
    });
    errdefer device.releaseBuffer(buffer_copy);

    // Setup transfer buffers.
    const download_transfer_buffer = try device.createTransferBuffer(.{
        .usage = .download,
        .size = @intCast(image_bytes.len + buffer_data_bytes.len),
    });
    defer device.releaseTransferBuffer(download_transfer_buffer);
    const upload_transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = @intCast(image_bytes.len + buffer_data_bytes.len),
    });
    defer device.releaseTransferBuffer(upload_transfer_buffer);
    {
        const transfer_buffer_mapped = try device.mapTransferBuffer(upload_transfer_buffer, false);
        defer device.unmapTransferBuffer(upload_transfer_buffer);
        @memcpy(transfer_buffer_mapped[0..image_bytes.len], image_bytes);
        @memcpy(transfer_buffer_mapped[image_bytes.len .. image_bytes.len + buffer_data_bytes.len], buffer_data_bytes);
    }

    // Upload transfer data.
    const cmd_buf = try device.acquireCommandBuffer();
    {
        const copy_pass = cmd_buf.beginCopyPass();
        defer copy_pass.end();
        copy_pass.uploadToTexture(
            .{
                .transfer_buffer = upload_transfer_buffer,
                .offset = 0,
            },
            .{
                .texture = original_texture,
                .width = @intCast(image_data.getWidth()),
                .height = @intCast(image_data.getHeight()),
                .depth = 1,
            },
            false,
        );
        copy_pass.textureToTexture(
            .{
                .texture = original_texture,
            },
            .{
                .texture = texture_copy,
            },
            @intCast(image_data.getWidth()),
            @intCast(image_data.getHeight()),
            1,
            false,
        );
        copy_pass.uploadToBuffer(
            .{
                .transfer_buffer = upload_transfer_buffer,
                .offset = @intCast(image_bytes.len),
            },
            .{
                .buffer = original_buffer,
                .offset = 0,
                .size = buffer_data_bytes.len,
            },
            false,
        );
        copy_pass.bufferToBuffer(
            .{
                .buffer = original_buffer,
                .offset = 0,
            },
            .{
                .buffer = buffer_copy,
                .offset = 0,
            },
            buffer_data_bytes.len,
            false,
        );
    }

    // Render the half-size version.
    cmd_buf.blitTexture(.{
        .source = .{
            .texture = original_texture,
            .region = .{ .x = 0, .y = 0, .w = @intCast(image_data.getWidth()), .h = @intCast(image_data.getHeight()) },
        },
        .destination = .{
            .texture = texture_small,
            .region = .{ .x = 0, .y = 0, .w = @intCast(image_data.getWidth() / 2), .h = @intCast(image_data.getHeight() / 2) },
        },
        .load_op = .do_not_care,
        .filter = .linear,
    });

    // Download original bytes from copies.
    {
        const copy_pass = cmd_buf.beginCopyPass();
        defer copy_pass.end();
        copy_pass.downloadFromTexture(
            .{
                .texture = texture_copy,
                .width = @intCast(image_data.getWidth()),
                .height = @intCast(image_data.getHeight()),
                .depth = 1,
            },
            .{
                .transfer_buffer = download_transfer_buffer,
                .offset = 0,
            },
        );
        copy_pass.downloadFromBuffer(
            .{
                .buffer = original_buffer,
                .offset = 0,
                .size = buffer_data_bytes.len,
            },
            .{
                .transfer_buffer = download_transfer_buffer,
                .offset = @intCast(image_bytes.len),
            },
        );
    }

    // Wait for commands.
    const fence = try cmd_buf.submitAndAcquireFence();
    defer device.releaseFence(fence);
    try device.waitForFences(
        true,
        &.{
            fence,
        },
    );

    // Compare downloaded data.
    {
        const download_buffer_mapped = try device.mapTransferBuffer(download_transfer_buffer, false);
        defer device.unmapTransferBuffer(download_transfer_buffer);
        if (std.mem.eql(u8, image_bytes, download_buffer_mapped[0..image_bytes.len])) {
            try sdl3.log.log("SUCCESS! Original texture bytes and the downloaded bytes match!", .{});
        } else {
            try sdl3.log.log("FAILURE! Original texture bytes do not match downloaded bytes!", .{});
        }
        if (std.mem.eql(u8, buffer_data_bytes, download_buffer_mapped[image_bytes.len .. image_bytes.len + buffer_data_bytes.len])) {
            try sdl3.log.log("SUCCESS! Original buffer bytes and the downloaded bytes match!", .{});
        } else {
            try sdl3.log.log("FAILURE! Original buffer bytes do not match downloaded bytes!", .{});
        }
    }

    // Prepare app state.
    const state = try allocator.create(AppState);
    errdefer allocator.destroy(state);
    state.* = .{
        .device = device,
        .window = window,
        .buffer_copy = buffer_copy,
        .original_buffer = original_buffer,
        .original_texture = original_texture,
        .texture_copy = texture_copy,
        .texture_small = texture_small,
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

        // Just clear the screen.
        {
            const render_pass = cmd_buf.beginRenderPass(
                &.{
                    .{
                        .texture = texture,
                        .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
                        .load = .clear,
                    },
                },
                null,
            );
            defer render_pass.end();
        }
        cmd_buf.blitTexture(.{
            .source = .{
                .texture = app_state.original_texture,
                .region = .{ .x = 0, .y = 0, .w = app_state.texture_width, .h = app_state.texture_height },
            },
            .destination = .{
                .texture = texture,
                .region = .{ .x = 0, .y = 0, .w = swapchain_texture.width / 2, .h = swapchain_texture.height / 2 },
            },
            .load_op = .load,
            .filter = .nearest,
        });
        cmd_buf.blitTexture(.{
            .source = .{
                .texture = app_state.texture_copy,
                .region = .{ .x = 0, .y = 0, .w = app_state.texture_width, .h = app_state.texture_height },
            },
            .destination = .{
                .texture = texture,
                .region = .{ .x = swapchain_texture.width / 2, .y = 0, .w = swapchain_texture.width / 2, .h = swapchain_texture.height / 2 },
            },
            .load_op = .load,
            .filter = .nearest,
        });
        cmd_buf.blitTexture(.{
            .source = .{
                .texture = app_state.texture_small,
                .region = .{ .x = 0, .y = 0, .w = app_state.texture_width / 2, .h = app_state.texture_height / 2 },
            },
            .destination = .{
                .texture = texture,
                .region = .{ .x = swapchain_texture.width / 4, .y = swapchain_texture.height / 2, .w = swapchain_texture.width / 2, .h = swapchain_texture.height / 2 },
            },
            .load_op = .load,
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
        val.device.releaseBuffer(val.buffer_copy);
        val.device.releaseBuffer(val.original_buffer);
        val.device.releaseTexture(val.texture_small);
        val.device.releaseTexture(val.texture_copy);
        val.device.releaseTexture(val.original_texture);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
