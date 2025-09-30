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

const comp_shader_source = @embedFile("texturedQuad.comp");
const comp_shader_name = "Textured Quad";

const ravioli_bmp = @embedFile("images/ravioli.bmp");

const window_width = 640;
const window_height = 480;

const sampler_names = [_][]const u8{
    "PointClamp",
    "PointWrap",
    "LinearClamp",
    "LinearWrap",
    "AnisotropicClamp",
    "AnisotropicWrap",
};

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    pipeline: sdl3.gpu.ComputePipeline,
    pipeline_metadata: sdl3.shadercross.ComputePipelineMetadata,
    texture: sdl3.gpu.Texture,
    write_texture: sdl3.gpu.Texture,
    samplers: [sampler_names.len]sdl3.gpu.Sampler,
    curr_sampler: usize = 0,
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
    const window = try sdl3.video.Window.init("Compute Sampler", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Load the image.
    const image_data = try loadImage(ravioli_bmp);
    defer image_data.deinit();
    const image_bytes = image_data.getPixels().?[0 .. image_data.getWidth() * image_data.getHeight() * @sizeOf(u8) * 4];

    // Create textures.
    const texture = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .format = .r8g8b8a8_unorm,
        .width = @intCast(image_data.getWidth()),
        .height = @intCast(image_data.getHeight()),
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = .{ .sampler = true },
        .props = .{ .name = "Ravioli Texture" },
    });
    errdefer device.releaseTexture(texture);
    const write_texture = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .format = .r8g8b8a8_unorm,
        .width = window_width,
        .height = window_height,
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = .{ .sampler = true, .compute_storage_write = true },
        .props = .{ .name = "Ravioli Texture" },
    });
    errdefer device.releaseTexture(write_texture);

    // Create pipeline.
    const pipeline = try loadComputeShader(device, comp_shader_name, comp_shader_source);
    errdefer device.releaseComputePipeline(pipeline.pipeline);

    // Create samplers.
    var samplers: [sampler_names.len]sdl3.gpu.Sampler = undefined;
    samplers[0] = try device.createSampler(.{
        .min_filter = .nearest,
        .mag_filter = .nearest,
        .mipmap_mode = .nearest,
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
    });
    errdefer device.releaseSampler(samplers[0]);
    samplers[1] = try device.createSampler(.{
        .min_filter = .nearest,
        .mag_filter = .nearest,
        .mipmap_mode = .nearest,
        .address_mode_u = .repeat,
        .address_mode_v = .repeat,
        .address_mode_w = .repeat,
    });
    errdefer device.releaseSampler(samplers[1]);
    samplers[2] = try device.createSampler(.{
        .min_filter = .linear,
        .mag_filter = .linear,
        .mipmap_mode = .linear,
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
    });
    errdefer device.releaseSampler(samplers[2]);
    samplers[3] = try device.createSampler(.{
        .min_filter = .linear,
        .mag_filter = .linear,
        .mipmap_mode = .linear,
        .address_mode_u = .repeat,
        .address_mode_v = .repeat,
        .address_mode_w = .repeat,
    });
    errdefer device.releaseSampler(samplers[3]);
    samplers[4] = try device.createSampler(.{
        .min_filter = .linear,
        .mag_filter = .linear,
        .mipmap_mode = .linear,
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
        .max_anisotropy = 4,
    });
    errdefer device.releaseSampler(samplers[4]);
    samplers[5] = try device.createSampler(.{
        .min_filter = .linear,
        .mag_filter = .linear,
        .mipmap_mode = .linear,
        .address_mode_u = .repeat,
        .address_mode_v = .repeat,
        .address_mode_w = .repeat,
        .max_anisotropy = 4,
    });
    errdefer device.releaseSampler(samplers[5]);

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
                .texture = texture,
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
        .pipeline = pipeline.pipeline,
        .pipeline_metadata = pipeline.metadata,
        .texture = texture,
        .write_texture = write_texture,
        .samplers = samplers,
    };

    // Finish setup.
    try sdl3.log.log("Press left/right to switch between sampler states", .{});
    try sdl3.log.log("Sampler state: {s}", .{sampler_names[state.curr_sampler]});
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

        // Start a compute pass if the swapchain texture is available.
        {
            const compute_pass = cmd_buf.beginComputePass(
                &.{
                    .{
                        .texture = app_state.write_texture,
                        .cycle = true,
                    },
                },
                &.{},
            );
            defer compute_pass.end();
            compute_pass.bindPipeline(app_state.pipeline);
            compute_pass.bindSamplers(
                0,
                &.{
                    .{ .texture = app_state.texture, .sampler = app_state.samplers[app_state.curr_sampler] },
                },
            );
            cmd_buf.pushComputeUniformData(0, std.mem.asBytes(&@as(f32, 0.25)));
            compute_pass.dispatch(
                swapchain_texture.width / app_state.pipeline_metadata.threadcount_x,
                swapchain_texture.height / app_state.pipeline_metadata.threadcount_y,
                app_state.pipeline_metadata.threadcount_z,
            );
        }
        cmd_buf.blitTexture(.{
            .source = .{
                .texture = app_state.write_texture,
                .region = .{ .x = 0, .y = 0, .w = window_width, .h = window_height },
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
    switch (curr_event) {
        .key_down => |key| {
            if (!key.repeat) {
                var changed = false;
                if (key.key) |val| switch (val) {
                    .left => {
                        if (app_state.curr_sampler == 0) {
                            app_state.curr_sampler = sampler_names.len - 1;
                        } else app_state.curr_sampler -= 1;
                        changed = true;
                    },
                    .right => {
                        if (app_state.curr_sampler >= sampler_names.len - 1) {
                            app_state.curr_sampler = 0;
                        } else app_state.curr_sampler += 1;
                        changed = true;
                    },
                    else => {},
                };
                if (changed) {
                    try sdl3.log.log("Sampler state: {s}", .{sampler_names[app_state.curr_sampler]});
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
        for (val.samplers) |sampler|
            val.device.releaseSampler(sampler);
        val.device.releaseTexture(val.write_texture);
        val.device.releaseTexture(val.texture);
        val.device.releaseComputePipeline(val.pipeline);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
