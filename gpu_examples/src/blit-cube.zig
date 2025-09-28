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

const vert_shader_source = @embedFile("skybox.vert");
const vert_shader_name = "Skybox";
const frag_shader_source = @embedFile("skybox.frag");
const frag_shader_name = "Skybox";

const window_width = 640;
const window_height = 480;

const tex_size = 32;

const PositionVertex = packed struct {
    position: @Vector(3, f32),
};

const vertices = [_]PositionVertex{
    .{ .position = .{ -10, -10, -10 } },
    .{ .position = .{ 10, -10, -10 } },
    .{ .position = .{ 10, 10, -10 } },
    .{ .position = .{ -10, 10, -10 } },

    .{ .position = .{ -10, -10, 10 } },
    .{ .position = .{ 10, -10, 10 } },
    .{ .position = .{ 10, 10, 10 } },
    .{ .position = .{ -10, 10, 10 } },

    .{ .position = .{ -10, -10, -10 } },
    .{ .position = .{ -10, 10, -10 } },
    .{ .position = .{ -10, 10, 10 } },
    .{ .position = .{ -10, -10, 10 } },

    .{ .position = .{ 10, -10, -10 } },
    .{ .position = .{ 10, 10, -10 } },
    .{ .position = .{ 10, 10, 10 } },
    .{ .position = .{ 10, -10, 10 } },

    .{ .position = .{ -10, -10, -10 } },
    .{ .position = .{ -10, -10, 10 } },
    .{ .position = .{ 10, -10, 10 } },
    .{ .position = .{ 10, -10, -10 } },

    .{ .position = .{ -10, 10, -10 } },
    .{ .position = .{ -10, 10, 10 } },
    .{ .position = .{ 10, 10, 10 } },
    .{ .position = .{ 10, 10, -10 } },
};
const vertices_bytes = std.mem.asBytes(&vertices);

const indices = [_]u16{ 0, 1, 2, 0, 2, 3, 6, 5, 4, 7, 6, 4, 8, 9, 10, 8, 10, 11, 14, 13, 12, 15, 14, 12, 16, 17, 18, 16, 18, 19, 22, 21, 20, 23, 22, 20 };
const indices_bytes = std.mem.asBytes(&indices);

const images = [_][]const u8{
    @embedFile("images/cube0.bmp"),
    @embedFile("images/cube1.bmp"),
    @embedFile("images/cube2.bmp"),
    @embedFile("images/cube3.bmp"),
    @embedFile("images/cube4.bmp"),
    @embedFile("images/cube5.bmp"),
};

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    pipeline: sdl3.gpu.GraphicsPipeline,
    vertex_buffer: sdl3.gpu.Buffer,
    index_buffer: sdl3.gpu.Buffer,
    source_texture: sdl3.gpu.Texture,
    destination_texture: sdl3.gpu.Texture,
    sampler: sdl3.gpu.Sampler,
    cam_pos: @Vector(3, f32) = .{ 0, 0, 4 },
};

const Mat4 = packed struct {
    c0: @Vector(4, f32),
    c1: @Vector(4, f32),
    c2: @Vector(4, f32),
    c3: @Vector(4, f32),

    pub fn lookAt(camera_position: @Vector(3, f32), camera_target: @Vector(3, f32), camera_up_vector: @Vector(3, f32)) Mat4 {
        const target_to_position = camera_position - camera_target;
        const a = (Vec3{ .data = target_to_position }).normalize();
        const b = (Vec3{ .data = camera_up_vector }).cross(a).normalize();
        const c = a.cross(b);
        return .{
            .c0 = .{ b.data[0], c.data[0], a.data[0], 0 },
            .c1 = .{ b.data[1], c.data[1], a.data[1], 0 },
            .c2 = .{ b.data[2], c.data[2], a.data[2], 0 },
            .c3 = .{ -b.dot(.{ .data = camera_position }), -c.dot(.{ .data = camera_position }), -a.dot(.{ .data = camera_position }), 1 },
        };
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        const ar0 = a.row(0);
        const ar1 = a.row(1);
        const ar2 = a.row(2);
        const ar3 = a.row(3);
        return .{
            .c0 = .{ @reduce(.Add, ar0 * b.c0), @reduce(.Add, ar1 * b.c0), @reduce(.Add, ar2 * b.c0), @reduce(.Add, ar3 * b.c0) },
            .c1 = .{ @reduce(.Add, ar0 * b.c1), @reduce(.Add, ar1 * b.c1), @reduce(.Add, ar2 * b.c1), @reduce(.Add, ar3 * b.c1) },
            .c2 = .{ @reduce(.Add, ar0 * b.c2), @reduce(.Add, ar1 * b.c2), @reduce(.Add, ar2 * b.c2), @reduce(.Add, ar3 * b.c2) },
            .c3 = .{ @reduce(.Add, ar0 * b.c3), @reduce(.Add, ar1 * b.c3), @reduce(.Add, ar2 * b.c3), @reduce(.Add, ar3 * b.c3) },
        };
    }

    pub fn perspectiveFieldOfView(field_of_view: f32, aspect_ratio: f32, near_plane_distance: f32, far_plane_distance: f32) Mat4 {
        const num = 1 / @tan(field_of_view * 0.5);
        return .{
            .c0 = .{ num / aspect_ratio, 0, 0, 0 },
            .c1 = .{ 0, num, 0, 0 },
            .c2 = .{ 0, 0, far_plane_distance / (near_plane_distance - far_plane_distance), -1 },
            .c3 = .{ 0, 0, (near_plane_distance * far_plane_distance) / (near_plane_distance - far_plane_distance), 0 },
        };
    }

    pub fn row(mat: Mat4, ind: comptime_int) @Vector(4, f32) {
        return switch (ind) {
            0 => .{ mat.c0[0], mat.c1[0], mat.c2[0], mat.c3[0] },
            1 => .{ mat.c0[1], mat.c1[1], mat.c2[1], mat.c3[1] },
            2 => .{ mat.c0[2], mat.c1[2], mat.c2[2], mat.c3[2] },
            3 => .{ mat.c0[3], mat.c1[3], mat.c2[3], mat.c3[3] },
            else => @compileError("Invalid row number"),
        };
    }
};

const Vec3 = struct {
    data: @Vector(3, f32),

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{ .data = .{
            a.data[1] * b.data[2] - b.data[1] * a.data[2],
            -(a.data[0] * b.data[2] - b.data[0] * a.data[2]),
            a.data[0] * b.data[1] - b.data[0] * a.data[1],
        } };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        const mul = a.data * b.data;
        return @reduce(.Add, mul);
    }

    pub fn normalize(self: Vec3) Vec3 {
        const mag = @sqrt(self.dot(self));
        return .{ .data = self.data / @as(@Vector(3, f32), @splat(mag)) };
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
    const window = try sdl3.video.Window.init("Cubemap", window_width, window_height, .{});
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
                },
            },
        },
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
        .vertex_input_state = .{
            .vertex_buffer_descriptions = &.{
                .{
                    .slot = 0,
                    .pitch = @sizeOf(PositionVertex),
                    .input_rate = .vertex,
                },
            },
            .vertex_attributes = &.{
                .{
                    .location = 0,
                    .buffer_slot = 0,
                    .format = .f32x3,
                    .offset = @offsetOf(PositionVertex, "position"),
                },
            },
        },
    };
    const pipeline = try device.createGraphicsPipeline(pipeline_create_info);
    errdefer device.releaseGraphicsPipeline(pipeline);

    // Create sampler.
    const sampler = try device.createSampler(.{
        .min_filter = .nearest,
        .mag_filter = .nearest,
        .mipmap_mode = .nearest,
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
    });

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

    // Create textures.
    const source_texture = try device.createTexture(.{
        .texture_type = .cube,
        .format = .r8g8b8a8_unorm,
        .width = tex_size,
        .height = tex_size,
        .layer_count_or_depth = images.len,
        .num_levels = 1,
        .usage = .{ .sampler = true },
        .props = .{ .name = "Cubemap Textures Source" },
    });
    errdefer device.releaseTexture(source_texture);
    const destination_texture = try device.createTexture(.{
        .texture_type = .cube,
        .format = .r8g8b8a8_unorm,
        .width = tex_size,
        .height = tex_size,
        .layer_count_or_depth = images.len,
        .num_levels = 1,
        .usage = .{ .sampler = true, .color_target = true },
        .props = .{ .name = "Cubemap Textures Destination" },
    });
    errdefer device.releaseTexture(destination_texture);

    // Load images.
    const cube0 = try loadImage(images[0]);
    defer cube0.deinit();
    const cube1 = try loadImage(images[1]);
    defer cube1.deinit();
    const cube2 = try loadImage(images[2]);
    defer cube2.deinit();
    const cube3 = try loadImage(images[3]);
    defer cube3.deinit();
    const cube4 = try loadImage(images[4]);
    defer cube4.deinit();
    const cube5 = try loadImage(images[5]);
    defer cube5.deinit();
    const cubes = [_]sdl3.surface.Surface{ cube0, cube1, cube2, cube3, cube4, cube5 };

    // Setup transfer buffer.
    const transfer_buffer_vertex_data_off = 0;
    const transfer_buffer_index_data_off = transfer_buffer_vertex_data_off + vertices_bytes.len;
    const transfer_images_off = transfer_buffer_index_data_off + indices_bytes.len;
    const image_size = cube0.getWidth() * cube0.getHeight() * @sizeOf(u8) * 4;
    const transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = @intCast(vertices_bytes.len + indices_bytes.len + image_size * images.len),
    });
    defer device.releaseTransferBuffer(transfer_buffer);
    {
        const transfer_buffer_mapped = try device.mapTransferBuffer(transfer_buffer, false);
        defer device.unmapTransferBuffer(transfer_buffer);
        @memcpy(transfer_buffer_mapped[transfer_buffer_vertex_data_off .. transfer_buffer_vertex_data_off + vertices_bytes.len], vertices_bytes);
        @memcpy(transfer_buffer_mapped[transfer_buffer_index_data_off .. transfer_buffer_index_data_off + indices_bytes.len], indices_bytes);
        for (0..images.len) |ind| {
            @memcpy(
                transfer_buffer_mapped[transfer_images_off + image_size * ind .. transfer_images_off + image_size * (ind + 1)],
                cubes[ind].getPixels().?[0 .. cubes[ind].getWidth() * cubes[ind].getHeight() * @sizeOf(u8) * 4],
            );
        }
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
        for (0..images.len) |ind| {
            copy_pass.uploadToTexture(.{
                .transfer_buffer = transfer_buffer,
                .offset = @intCast(transfer_images_off + image_size * ind),
            }, .{
                .texture = source_texture,
                .layer = @intCast(ind),
                .width = tex_size,
                .height = tex_size,
                .depth = 1,
            }, false);
        }
    }

    // Blit to destination texture.
    // This serves no real purpose other than demonstrating cube->cube blits are possible!
    for (0..images.len) |ind|
        cmd_buf.blitTexture(.{
            .source = .{
                .texture = source_texture,
                .region = .{ .x = 0, .y = 0, .w = tex_size, .h = tex_size },
                .layer_or_depth_plane = @intCast(ind),
            },
            .destination = .{
                .texture = destination_texture,
                .region = .{ .x = 0, .y = 0, .w = tex_size, .h = tex_size },
                .layer_or_depth_plane = @intCast(ind),
            },
            .load_op = .do_not_care,
            .filter = .linear,
        });
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
        .source_texture = source_texture,
        .destination_texture = destination_texture,
        .sampler = sampler,
    };

    // Finish setup.
    try sdl3.log.log("Press left/right to view the opposite direction", .{});
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
                .{ .texture = app_state.destination_texture, .sampler = app_state.sampler },
            },
        );
        cmd_buf.pushVertexUniformData(0, std.mem.asBytes(&Mat4.perspectiveFieldOfView(
            75.0 * std.math.pi / 180.0,
            @as(comptime_float, window_width) / @as(comptime_float, window_height),
            0.01,
            100,
        ).mul(Mat4.lookAt(
            app_state.cam_pos,
            .{ 0, 0, 0 },
            .{ 0, 1, 0 },
        ))));
        render_pass.drawIndexedPrimitives(36, 1, 0, 0, 0);
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
                if (key.key) |val| switch (val) {
                    .left, .right => {
                        app_state.cam_pos[2] = -app_state.cam_pos[2];
                    },
                    else => {},
                };
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
        val.device.releaseSampler(val.sampler);
        val.device.releaseTexture(val.destination_texture);
        val.device.releaseTexture(val.source_texture);
        val.device.releaseBuffer(val.index_buffer);
        val.device.releaseBuffer(val.vertex_buffer);
        val.device.releaseGraphicsPipeline(val.pipeline);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
