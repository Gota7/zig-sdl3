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

const vert_shader_source = @embedFile("texturedQuadWithMatrix.vert");
const vert_shader_name = "Textured Quad With Matrix";
const frag_shader_source = @embedFile("texturedQuadWithMultiplyColor.frag");
const frag_shader_name = "Textured Quad With Multiply Color";

const ravioli_bmp = @embedFile("images/ravioli.bmp");

const window_width = 640;
const window_height = 480;

const PositionTextureVertex = packed struct {
    position: @Vector(3, f32),
    tex_coord: @Vector(2, f32),
};

const vertices = [_]PositionTextureVertex{
    .{ .position = .{ -0.5, -0.5, 0 }, .tex_coord = .{ 0, 0 } },
    .{ .position = .{ 0.5, -0.5, 0 }, .tex_coord = .{ 1, 0 } },
    .{ .position = .{ 0.5, 0.5, 0 }, .tex_coord = .{ 1, 1 } },
    .{ .position = .{ -0.5, 0.5, 0 }, .tex_coord = .{ 0, 1 } },
};
const vertices_bytes = std.mem.asBytes(&vertices);

const indices = [_]u16{
    0,
    1,
    2,
    0,
    2,
    3,
};
const indices_bytes = std.mem.asBytes(&indices);

const FragMultiplyUniform = packed struct {
    data: @Vector(4, f32),
};

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    pipeline: sdl3.gpu.GraphicsPipeline,
    vertex_buffer: sdl3.gpu.Buffer,
    index_buffer: sdl3.gpu.Buffer,
    texture: sdl3.gpu.Texture,
    sampler: sdl3.gpu.Sampler,
};

const Mat4 = struct {
    c: [4]@Vector(4, f32),

    fn mulVec(a: Mat4, b: @Vector(4, f32)) @Vector(4, f32) {
        const Vec = @Vector(4, f32);
        var sum: Vec = @splat(0);
        inline for (0..4) |i| {
            sum += a.c[i] * @as(Vec, @splat(b[i]));
        }
        return sum;
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var res: Mat4 = undefined;
        inline for (0..4) |i| {
            res.c[i] = a.mulVec(b.c[i]);
        }
        return res;
    }

    pub fn rotationZ(radians: f32) Mat4 {
        return .{
            .c = .{
                .{ @cos(radians), @sin(radians), 0, 0 },
                .{ -@sin(radians), @cos(radians), 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn translation(amount: @Vector(3, f32)) Mat4 {
        return .{
            .c = .{
                .{ 1, 0, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ amount[0], amount[1], amount[2], 1 },
            },
        };
    }
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
    const window = try sdl3.video.Window.init("Textured Animated Quad", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Prepare pipelines.
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
                        .alpha_blend = .add,
                        .color_blend = .add,
                        .source_color = .src_alpha,
                        .source_alpha = .src_alpha,
                        .destination_color = .one_minus_src_alpha,
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
                    .pitch = @sizeOf(PositionTextureVertex),
                    .input_rate = .vertex,
                },
            },
            .vertex_attributes = &.{
                .{
                    .location = 0,
                    .buffer_slot = 0,
                    .format = .f32x3,
                    .offset = @offsetOf(PositionTextureVertex, "position"),
                },
                .{
                    .location = 1,
                    .buffer_slot = 0,
                    .format = .f32x2,
                    .offset = @offsetOf(PositionTextureVertex, "tex_coord"),
                },
            },
        },
    };
    const pipeline = try device.createGraphicsPipeline(pipeline_create_info);
    errdefer device.releaseGraphicsPipeline(pipeline);

    // Prepare vertex buffer.
    const vertex_buffer = try device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = vertices_bytes.len,
    });
    errdefer device.releaseBuffer(vertex_buffer);

    // Create the index buffer.
    const index_buffer = try device.createBuffer(.{
        .usage = .{ .index = true },
        .size = indices_bytes.len,
    });
    errdefer device.releaseBuffer(index_buffer);

    // Load the image.
    const image_data = try loadImage(ravioli_bmp);
    defer image_data.deinit();
    const image_bytes = image_data.getPixels().?[0 .. image_data.getWidth() * image_data.getHeight() * @sizeOf(u8) * 4];

    // Create texture.
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

    // Create sampler.
    const sampler = try device.createSampler(.{
        .min_filter = .nearest,
        .mag_filter = .nearest,
        .mipmap_mode = .nearest,
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
    });
    errdefer device.releaseSampler(sampler);

    // Setup transfer buffer.
    const transfer_buffer_vertex_data_off = 0;
    const transfer_buffer_index_data_off = transfer_buffer_vertex_data_off + vertices_bytes.len;
    const transfer_buffer_image_data_off = transfer_buffer_index_data_off + indices_bytes.len;
    const transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = @intCast(vertices_bytes.len + indices_bytes.len + image_bytes.len),
    });
    defer device.releaseTransferBuffer(transfer_buffer);
    {
        const transfer_buffer_mapped = try device.mapTransferBuffer(transfer_buffer, false);
        defer device.unmapTransferBuffer(transfer_buffer);
        @memcpy(transfer_buffer_mapped[transfer_buffer_vertex_data_off .. transfer_buffer_vertex_data_off + vertices_bytes.len], vertices_bytes);
        @memcpy(transfer_buffer_mapped[transfer_buffer_index_data_off .. transfer_buffer_index_data_off + indices_bytes.len], indices_bytes);
        @memcpy(transfer_buffer_mapped[transfer_buffer_image_data_off .. transfer_buffer_image_data_off + image_bytes.len], image_bytes);
    }

    // Upload transfer data.
    const cmd_buf = try device.acquireCommandBuffer();
    {
        const copy_pass = cmd_buf.beginCopyPass();
        defer copy_pass.end();
        copy_pass.uploadToBuffer(
            .{
                .transfer_buffer = transfer_buffer,
                .offset = transfer_buffer_vertex_data_off,
            },
            .{
                .buffer = vertex_buffer,
                .offset = 0,
                .size = vertices_bytes.len,
            },
            false,
        );
        copy_pass.uploadToBuffer(
            .{
                .transfer_buffer = transfer_buffer,
                .offset = transfer_buffer_index_data_off,
            },
            .{
                .buffer = index_buffer,
                .offset = 0,
                .size = indices_bytes.len,
            },
            false,
        );
        copy_pass.uploadToTexture(
            .{
                .transfer_buffer = transfer_buffer,
                .offset = transfer_buffer_image_data_off,
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
        .pipeline = pipeline,
        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,
        .texture = texture,
        .sampler = sampler,
    };

    // Finish setup.
    app_state.* = state;
    return .run;
}

pub fn iterate(
    app_state: *AppState,
) !sdl3.AppResult {
    const time = @as(f32, @floatFromInt(sdl3.timer.getMillisecondsSinceInit())) / 1000;

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
        render_pass.bindVertexBuffers(
            0,
            &.{
                .{ .buffer = app_state.vertex_buffer, .offset = 0 },
            },
        );
        render_pass.bindIndexBuffer(
            .{ .buffer = app_state.index_buffer, .offset = 0 },
            .indices_16bit,
        );
        render_pass.bindFragmentSamplers(
            0,
            &.{
                .{ .texture = app_state.texture, .sampler = app_state.sampler },
            },
        );

        // Top-left.
        cmd_buf.pushVertexUniformData(0, std.mem.asBytes(&Mat4.translation(.{ -0.5, -0.5, 0 }).mul(Mat4.rotationZ(time))));
        cmd_buf.pushFragmentUniformData(0, std.mem.asBytes(&FragMultiplyUniform{ .data = .{ 1, 0.5 + @sin(time) * 0.5, 1, 1 } }));
        render_pass.drawIndexedPrimitives(6, 1, 0, 0, 0);

        // Top-right.
        cmd_buf.pushVertexUniformData(0, std.mem.asBytes(&Mat4.translation(.{ 0.5, -0.5, 0 }).mul(Mat4.rotationZ((2 * std.math.pi) - time))));
        cmd_buf.pushFragmentUniformData(0, std.mem.asBytes(&FragMultiplyUniform{ .data = .{ 1, 0.5 + @cos(time) * 0.5, 1, 1 } }));
        render_pass.drawIndexedPrimitives(6, 1, 0, 0, 0);

        // Bottom-left.
        cmd_buf.pushVertexUniformData(0, std.mem.asBytes(&Mat4.translation(.{ -0.5, 0.5, 0 }).mul(Mat4.rotationZ(time))));
        cmd_buf.pushFragmentUniformData(0, std.mem.asBytes(&FragMultiplyUniform{ .data = .{ 1, 0.5 + @sin(time) * 0.2, 1, 1 } }));
        render_pass.drawIndexedPrimitives(6, 1, 0, 0, 0);

        // Bottom-right.
        cmd_buf.pushVertexUniformData(0, std.mem.asBytes(&Mat4.translation(.{ 0.5, 0.5, 0 }).mul(Mat4.rotationZ(time))));
        cmd_buf.pushFragmentUniformData(0, std.mem.asBytes(&FragMultiplyUniform{ .data = .{ 1, 0.5 + @cos(time), 1, 1 } }));
        render_pass.drawIndexedPrimitives(6, 1, 0, 0, 0);
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
        val.device.releaseSampler(val.sampler);
        val.device.releaseTexture(val.texture);
        val.device.releaseBuffer(val.index_buffer);
        val.device.releaseBuffer(val.vertex_buffer);
        val.device.releaseGraphicsPipeline(val.pipeline);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
