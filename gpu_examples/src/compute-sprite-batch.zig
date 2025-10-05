// This example is slightly inferior in terms of performance compared to `pull-sprite-batch.zig`.
// Despite that, it is included as an example of a compute to graphics workflow.
//
// ALSO NOTE: DUE TO A MISCOMPILATION, THIS EXAMPLE MUST BE BUILT USING LLVM! SO USING `-Doptimize=ReleaseFast` SHOULD FIX THE BLACK SCREEN!

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

const vert_shader_source = @embedFile("texturedQuadColorWithMatrix.vert");
const vert_shader_name = "Textured Quad Color With Matrix";
const frag_shader_source = @embedFile("texturedQuadColor.frag");
const frag_shader_name = "Textured Quad Color";
const comp_shader_source = @embedFile("spriteBatch.comp");
const comp_shader_name = "Sprite Batch";

const ravioli_atlas_bmp = @embedFile("images/ravioliAtlas.bmp");

const window_width = 640;
const window_height = 480;

const sprite_size = 32;
const sprite_count = 8192;

const PositionTextureColorVertex = packed struct {
    position: @Vector(4, f32),
    tex_coord: @Vector(2, f32),
    _: @Vector(2, f32) = .{ 0, 0 }, // Padding for STD140 requirements.
    color: @Vector(4, f32),
};

const ComputeSpriteInstance = packed struct {
    position: @Vector(3, f32),
    rotation: f32,
    size: @Vector(2, f32),
    _: @Vector(2, f32) = .{ 0, 0 }, // Padding for STD140 requirements.
    texture: @Vector(4, f32),
    color: @Vector(4, f32),
};

const ravioli_coords = [_]@Vector(2, f32){
    .{
        0,
        0,
    },
    .{
        0.5,
        0,
    },
    .{
        0,
        0.5,
    },
    .{
        0.5,
        0.5,
    },
};

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    compute_pipeline: sdl3.gpu.ComputePipeline,
    compute_pipeline_metadata: sdl3.shadercross.ComputePipelineMetadata,
    render_pipeline: sdl3.gpu.GraphicsPipeline,
    sampler: sdl3.gpu.Sampler,
    texture: sdl3.gpu.Texture,
    sprite_compute_transfer_buffer: sdl3.gpu.TransferBuffer,
    sprite_compute_buffer: sdl3.gpu.Buffer,
    sprite_vertex_buffer: sdl3.gpu.Buffer,
    sprite_index_buffer: sdl3.gpu.Buffer,
    prng: std.Random.DefaultPrng,
};

const Mat4 = packed struct {
    c0: @Vector(4, f32),
    c1: @Vector(4, f32),
    c2: @Vector(4, f32),
    c3: @Vector(4, f32),

    pub fn orthographicOffCenter(
        left: f32,
        right: f32,
        bottom: f32,
        top: f32,
        z_near: f32,
        z_far: f32,
    ) Mat4 {
        return .{
            .c0 = .{ 2 / (right - left), 0, 0, 0 },
            .c1 = .{ 0, 2 / (top - bottom), 0, 0 },
            .c2 = .{ 0, 0, 1 / (z_near - z_far), 0 },
            .c3 = .{ (left + right) / (left - right), (top + bottom) / (bottom - top), z_near / (z_near - z_far), 1 },
        };
    }
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
    const window = try sdl3.video.Window.init("Compute Sprite Batch", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Set present mode.
    var present_mode = sdl3.gpu.PresentMode.vsync;
    if (device.windowSupportsPresentMode(window, .immediate)) {
        present_mode = .immediate;
    } else if (device.windowSupportsPresentMode(window, .immediate)) {
        present_mode = .mailbox;
    }
    try device.setSwapchainParameters(window, .sdr, present_mode);

    // Create render pipeline.
    const vertex_shader = try loadGraphicsShader(device, vert_shader_name, vert_shader_source, .vertex);
    defer device.releaseShader(vertex_shader);
    const fragment_shader = try loadGraphicsShader(device, frag_shader_name, frag_shader_source, .fragment);
    defer device.releaseShader(fragment_shader);
    const pipeline_create_info = sdl3.gpu.GraphicsPipelineCreateInfo{
        .target_info = .{
            .color_target_descriptions = &.{
                .{
                    .format = try device.getSwapchainTextureFormat(window),
                    .blend_state = .{
                        .enable_blend = true,
                        .color_blend = .add,
                        .alpha_blend = .add,
                        .source_color = .src_alpha,
                        .destination_color = .one_minus_src_alpha,
                        .source_alpha = .src_alpha,
                        .destination_alpha = .one_minus_src_alpha,
                    },
                },
            },
        },
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
        .vertex_input_state = .{
            .vertex_buffer_descriptions = &.{
                .{
                    .slot = 0,
                    .pitch = @sizeOf(PositionTextureColorVertex),
                    .input_rate = .vertex,
                },
            },
            .vertex_attributes = &.{
                .{
                    .location = 0,
                    .buffer_slot = 0,
                    .format = .f32x4,
                    .offset = @offsetOf(PositionTextureColorVertex, "position"),
                },
                .{
                    .location = 1,
                    .buffer_slot = 0,
                    .format = .f32x2,
                    .offset = @offsetOf(PositionTextureColorVertex, "tex_coord"),
                },
                .{
                    .location = 2,
                    .buffer_slot = 0,
                    .format = .f32x4,
                    .offset = @offsetOf(PositionTextureColorVertex, "color"),
                },
            },
        },
    };
    const render_pipeline = try device.createGraphicsPipeline(pipeline_create_info);
    errdefer device.releaseGraphicsPipeline(render_pipeline);

    // Create compute pipeline.
    const compute_pipeline = try loadComputeShader(device, comp_shader_name, comp_shader_source);
    errdefer device.releaseComputePipeline(compute_pipeline.pipeline);

    // Load the image.
    const image_data = try loadImage(ravioli_atlas_bmp);
    defer image_data.deinit();
    const image_bytes = image_data.getPixels().?[0 .. image_data.getWidth() * image_data.getHeight() * @sizeOf(u8) * 4];

    // Create texture and sampler.
    const texture = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .format = .r8g8b8a8_unorm,
        .width = @intCast(image_data.getWidth()),
        .height = @intCast(image_data.getHeight()),
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = .{ .sampler = true },
        .props = .{ .name = "Ravioli Texture Atlas" },
    });
    errdefer device.releaseTexture(texture);

    // Create samplers.
    const sampler = try device.createSampler(.{
        .min_filter = .nearest,
        .mag_filter = .nearest,
        .mipmap_mode = .nearest,
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
    });
    errdefer device.releaseSampler(sampler);

    // Setup texture transfer buffer.
    const texture_transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = @intCast(image_bytes.len),
    });
    defer device.releaseTransferBuffer(texture_transfer_buffer);
    {
        const transfer_buffer_mapped = try device.mapTransferBuffer(texture_transfer_buffer, false);
        defer device.unmapTransferBuffer(texture_transfer_buffer);
        @memcpy(transfer_buffer_mapped[0..image_bytes.len], image_bytes);
    }

    // Create sprite resources.
    const sprite_compute_transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = @sizeOf(ComputeSpriteInstance) * sprite_count,
    });
    errdefer device.releaseTransferBuffer(sprite_compute_transfer_buffer);
    const sprite_compute_buffer = try device.createBuffer(.{
        .usage = .{ .compute_storage_read = true },
        .size = @sizeOf(ComputeSpriteInstance) * sprite_count,
    });
    errdefer device.releaseBuffer(sprite_compute_buffer);
    const sprite_vertex_buffer = try device.createBuffer(.{
        .usage = .{ .compute_storage_write = true, .vertex = true },
        .size = @sizeOf(PositionTextureColorVertex) * sprite_count * 4,
    });
    errdefer device.releaseBuffer(sprite_vertex_buffer);
    const sprite_index_buffer = try device.createBuffer(.{
        .usage = .{ .index = true },
        .size = @sizeOf(u32) * sprite_count * 6,
    });
    errdefer device.releaseBuffer(sprite_index_buffer);

    // Setup index transfer buffer.
    const index_transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = @sizeOf(u32) * sprite_count * 6,
    });
    defer device.releaseTransferBuffer(index_transfer_buffer);
    {
        const transfer_buffer_mapped = @as([*]u32, @ptrCast(@alignCast(try device.mapTransferBuffer(index_transfer_buffer, false))));
        defer device.unmapTransferBuffer(index_transfer_buffer);
        for (0..sprite_count) |sprite_ind| {
            const index_base = sprite_ind * 6;
            const val_base: u32 = @intCast(sprite_ind * 4);
            transfer_buffer_mapped[index_base + 0] = val_base + 0;
            transfer_buffer_mapped[index_base + 1] = val_base + 1;
            transfer_buffer_mapped[index_base + 2] = val_base + 2;
            transfer_buffer_mapped[index_base + 3] = val_base + 3;
            transfer_buffer_mapped[index_base + 4] = val_base + 2;
            transfer_buffer_mapped[index_base + 5] = val_base + 1;
        }
    }

    // Upload transfer data.
    const cmd_buf = try device.acquireCommandBuffer();
    {
        const copy_pass = cmd_buf.beginCopyPass();
        defer copy_pass.end();
        copy_pass.uploadToTexture(
            .{
                .transfer_buffer = texture_transfer_buffer,
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
        copy_pass.uploadToBuffer(
            .{
                .transfer_buffer = index_transfer_buffer,
                .offset = 0,
            },
            .{
                .buffer = sprite_index_buffer,
                .offset = 0,
                .size = @sizeOf(u32) * sprite_count * 6,
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
        .compute_pipeline = compute_pipeline.pipeline,
        .compute_pipeline_metadata = compute_pipeline.metadata,
        .render_pipeline = render_pipeline,
        .sprite_compute_transfer_buffer = sprite_compute_transfer_buffer,
        .sprite_compute_buffer = sprite_compute_buffer,
        .sprite_vertex_buffer = sprite_vertex_buffer,
        .sprite_index_buffer = sprite_index_buffer,
        .texture = texture,
        .sampler = sampler,
        .prng = .init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        }),
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

        // Build sprite instance buffer.
        {
            const sprite_data = @as([*]ComputeSpriteInstance, @ptrCast(@alignCast(try app_state.device.mapTransferBuffer(app_state.sprite_compute_transfer_buffer, true))));
            defer app_state.device.unmapTransferBuffer(app_state.sprite_compute_transfer_buffer);
            const random = app_state.prng.random();
            for (0..sprite_count) |sprite_ind| {
                const ravioli_ind = random.int(u2);
                sprite_data[sprite_ind] = .{
                    .position = .{ random.float(f32) * window_width, random.float(f32) * window_height, 0 },
                    .rotation = 2 * std.math.pi * random.float(f32),
                    .size = .{ sprite_size, sprite_size },
                    .texture = .{ ravioli_coords[ravioli_ind][0], ravioli_coords[ravioli_ind][1], 0.5, 0.5 },
                    .color = .{ 1, 1, 1, 1 },
                    ._ = .{ 69, 72 },
                };
            }
            std.debug.print("{any}\n", .{sprite_data[0]}); // Currently to prove miscompilation.
        }

        // Upload instance data.
        {
            const copy_pass = cmd_buf.beginCopyPass();
            defer copy_pass.end();
            copy_pass.uploadToBuffer(
                .{
                    .transfer_buffer = app_state.sprite_compute_transfer_buffer,
                    .offset = 0,
                },
                .{
                    .buffer = app_state.sprite_compute_buffer,
                    .offset = 0,
                    .size = @sizeOf(ComputeSpriteInstance) * sprite_count,
                },
                true,
            );
        }

        // Set up compute pass to build vertex buffer.
        {
            const compute_pass = cmd_buf.beginComputePass(
                &.{},
                &.{
                    .{
                        .buffer = app_state.sprite_vertex_buffer,
                        .cycle = true,
                    },
                },
            );
            defer compute_pass.end();
            compute_pass.bindPipeline(app_state.compute_pipeline);
            compute_pass.bindStorageBuffers(
                0,
                &.{
                    app_state.sprite_compute_buffer,
                },
            );
            cmd_buf.pushComputeUniformData(0, std.mem.asBytes(&@as(f32, 0.25)));
            compute_pass.dispatch(
                sprite_count / app_state.compute_pipeline_metadata.threadcount_x,
                app_state.compute_pipeline_metadata.threadcount_y,
                app_state.compute_pipeline_metadata.threadcount_z,
            );
        }

        // Render sprites.
        {
            const render_pass = cmd_buf.beginRenderPass(
                &.{
                    .{
                        .texture = texture,
                        .load = .clear,
                        .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
                    },
                },
                null,
            );
            defer render_pass.end();
            render_pass.bindGraphicsPipeline(app_state.render_pipeline);
            render_pass.bindVertexBuffers(
                0,
                &.{
                    .{
                        .buffer = app_state.sprite_vertex_buffer,
                        .offset = 0,
                    },
                },
            );
            render_pass.bindIndexBuffer(
                .{
                    .buffer = app_state.sprite_index_buffer,
                    .offset = 0,
                },
                .indices_32bit,
            );
            render_pass.bindFragmentSamplers(
                0,
                &.{
                    .{ .texture = app_state.texture, .sampler = app_state.sampler },
                },
            );
            cmd_buf.pushVertexUniformData(0, std.mem.asBytes(&Mat4.orthographicOffCenter(0, window_width, window_height, 0, 0, -1)));
            render_pass.drawIndexedPrimitives(sprite_count * 6, 1, 0, 0, 0);
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
        val.device.releaseBuffer(val.sprite_index_buffer);
        val.device.releaseBuffer(val.sprite_vertex_buffer);
        val.device.releaseBuffer(val.sprite_compute_buffer);
        val.device.releaseTransferBuffer(val.sprite_compute_transfer_buffer);
        val.device.releaseSampler(val.sampler);
        val.device.releaseTexture(val.texture);
        val.device.releaseComputePipeline(val.compute_pipeline);
        val.device.releaseGraphicsPipeline(val.render_pipeline);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
