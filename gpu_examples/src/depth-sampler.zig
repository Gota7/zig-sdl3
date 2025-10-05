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

const scene_vert_shader_source = @embedFile("positionColorTransform.vert");
const scene_vert_shader_name = "Position Color Transform";
const scene_frag_shader_source = @embedFile("solidColorDepth.frag");
const scene_frag_shader_name = "Solid Color Depth";
const effect_vert_shader_source = @embedFile("texturedQuad.vert");
const effect_vert_shader_name = "Textured Quad";
const effect_frag_shader_source = @embedFile("depthOutline.frag");
const effect_frag_shader_name = "Depth Outline";

const window_width = 640;
const window_height = 480;

const tex_size = 64;

const PositionColorVertex = packed struct {
    position: @Vector(3, f32),
    color: @Vector(4, u8),
};

const PositionTextureVertex = packed struct {
    position: @Vector(3, f32),
    tex_coord: @Vector(2, f32),
};

const scene_vertices = [_]PositionColorVertex{
    .{ .position = .{ -10, -10, -10 }, .color = .{ 255, 0, 0, 255 } },
    .{ .position = .{ 10, -10, -10 }, .color = .{ 255, 0, 0, 255 } },
    .{ .position = .{ 10, 10, -10 }, .color = .{ 255, 0, 0, 255 } },
    .{ .position = .{ -10, 10, -10 }, .color = .{ 255, 0, 0, 255 } },

    .{ .position = .{ -10, -10, 10 }, .color = .{ 255, 255, 0, 255 } },
    .{ .position = .{ 10, -10, 10 }, .color = .{ 255, 255, 0, 255 } },
    .{ .position = .{ 10, 10, 10 }, .color = .{ 255, 255, 0, 255 } },
    .{ .position = .{ -10, 10, 10 }, .color = .{ 255, 255, 0, 255 } },

    .{ .position = .{ -10, -10, -10 }, .color = .{ 255, 0, 255, 255 } },
    .{ .position = .{ -10, 10, -10 }, .color = .{ 255, 0, 255, 255 } },
    .{ .position = .{ -10, 10, 10 }, .color = .{ 255, 0, 255, 255 } },
    .{ .position = .{ -10, -10, 10 }, .color = .{ 255, 0, 255, 255 } },

    .{ .position = .{ 10, -10, -10 }, .color = .{ 0, 255, 0, 255 } },
    .{ .position = .{ 10, 10, -10 }, .color = .{ 0, 255, 0, 255 } },
    .{ .position = .{ 10, 10, 10 }, .color = .{ 0, 255, 0, 255 } },
    .{ .position = .{ 10, -10, 10 }, .color = .{ 0, 255, 0, 255 } },

    .{ .position = .{ -10, -10, -10 }, .color = .{ 0, 255, 255, 255 } },
    .{ .position = .{ -10, -10, 10 }, .color = .{ 0, 255, 255, 255 } },
    .{ .position = .{ 10, -10, 10 }, .color = .{ 0, 255, 255, 255 } },
    .{ .position = .{ 10, -10, -10 }, .color = .{ 0, 255, 255, 255 } },

    .{ .position = .{ -10, 10, -10 }, .color = .{ 0, 0, 255, 255 } },
    .{ .position = .{ -10, 10, 10 }, .color = .{ 0, 0, 255, 255 } },
    .{ .position = .{ 10, 10, 10 }, .color = .{ 0, 0, 255, 255 } },
    .{ .position = .{ 10, 10, -10 }, .color = .{ 0, 0, 255, 255 } },
};
const scene_vertices_bytes = std.mem.asBytes(&scene_vertices);

const effect_vertices = [_]PositionTextureVertex{
    .{ .position = .{ -1, 1, 0 }, .tex_coord = .{ 0, 0 } },
    .{ .position = .{ 1, 1, 0 }, .tex_coord = .{ 1, 0 } },
    .{ .position = .{ 1, -1, 0 }, .tex_coord = .{ 1, 1 } },
    .{ .position = .{ -1, -1, 0 }, .tex_coord = .{ 0, 1 } },
};
const effect_vertices_bytes = std.mem.asBytes(&effect_vertices);

const scene_indices = [_]u16{ 0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7, 8, 9, 10, 8, 10, 11, 12, 13, 14, 12, 14, 15, 16, 17, 18, 16, 18, 19, 20, 21, 22, 20, 22, 23 };
const scene_indices_bytes = std.mem.asBytes(&scene_indices);

const effect_indices = [_]u16{
    0,
    1,
    2,
    0,
    2,
    3,
};
const effect_indices_bytes = std.mem.asBytes(&effect_indices);

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    scene_pipeline: sdl3.gpu.GraphicsPipeline,
    scene_vertex_buffer: sdl3.gpu.Buffer,
    scene_index_buffer: sdl3.gpu.Buffer,
    scene_color_texture: sdl3.gpu.Texture,
    scene_depth_texture: sdl3.gpu.Texture,
    effect_pipeline: sdl3.gpu.GraphicsPipeline,
    effect_vertex_buffer: sdl3.gpu.Buffer,
    effect_index_buffer: sdl3.gpu.Buffer,
    effect_sampler: sdl3.gpu.Sampler,
    scene_width: u32,
    scene_height: u32,
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
    const window = try sdl3.video.Window.init("Depth Sampler", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Prepare pipelines.
    const scene_vertex_shader = try loadGraphicsShader(device, scene_vert_shader_name, scene_vert_shader_source, .vertex);
    defer device.releaseShader(scene_vertex_shader);
    const scene_fragment_shader = try loadGraphicsShader(device, scene_frag_shader_name, scene_frag_shader_source, .fragment);
    defer device.releaseShader(scene_fragment_shader);
    const scene_pipeline_create_info = sdl3.gpu.GraphicsPipelineCreateInfo{
        .target_info = .{
            .color_target_descriptions = &.{
                .{
                    .format = try device.getSwapchainTextureFormat(window),
                },
            },
            .depth_stencil_format = .depth16_unorm,
        },
        .depth_stencil_state = .{
            .enable_depth_test = true,
            .enable_depth_write = true,
            .compare = .less,
            .write_mask = 0xff,
        },
        .vertex_shader = scene_vertex_shader,
        .fragment_shader = scene_fragment_shader,
        .vertex_input_state = .{
            .vertex_buffer_descriptions = &.{
                .{
                    .slot = 0,
                    .pitch = @sizeOf(PositionColorVertex),
                    .input_rate = .vertex,
                },
            },
            .vertex_attributes = &.{
                .{
                    .location = 0,
                    .buffer_slot = 0,
                    .format = .f32x3,
                    .offset = @offsetOf(PositionColorVertex, "position"),
                },
                .{
                    .location = 1,
                    .buffer_slot = 0,
                    .format = .u8x4_normalized,
                    .offset = @offsetOf(PositionColorVertex, "color"),
                },
            },
        },
    };
    const scene_pipeline = try device.createGraphicsPipeline(scene_pipeline_create_info);
    errdefer device.releaseGraphicsPipeline(scene_pipeline);

    const effect_vertex_shader = try loadGraphicsShader(device, effect_vert_shader_name, effect_vert_shader_source, .vertex);
    defer device.releaseShader(effect_vertex_shader);
    const effect_fragment_shader = try loadGraphicsShader(device, effect_frag_shader_name, effect_frag_shader_source, .fragment);
    defer device.releaseShader(effect_fragment_shader);
    const effect_pipeline_create_info = sdl3.gpu.GraphicsPipelineCreateInfo{
        .target_info = .{
            .color_target_descriptions = &.{
                .{
                    .format = try device.getSwapchainTextureFormat(window),
                    .blend_state = .{
                        .enable_blend = true,
                        .source_color = .one,
                        .destination_color = .one_minus_src_alpha,
                        .color_blend = .add,
                        .source_alpha = .one,
                        .destination_alpha = .one_minus_src_alpha,
                        .alpha_blend = .add,
                    },
                },
            },
        },
        .vertex_shader = effect_vertex_shader,
        .fragment_shader = effect_fragment_shader,
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
    const effect_pipeline = try device.createGraphicsPipeline(effect_pipeline_create_info);
    errdefer device.releaseGraphicsPipeline(effect_pipeline);

    // Create textures.
    const scene_width = window_width / 4;
    const scene_height = window_height / 4;
    const scene_color_texture = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .format = .r8g8b8a8_unorm,
        .width = scene_width,
        .height = scene_height,
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = .{ .sampler = true, .color_target = true },
        .props = .{ .name = "Scene Color Texture" },
    });
    errdefer device.releaseTexture(scene_color_texture);
    const scene_depth_texture = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .format = .depth16_unorm,
        .width = scene_width,
        .height = scene_height,
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = .{ .sampler = true, .depth_stencil_target = true },
        .props = .{ .name = "Scene Depth Texture" },
    });
    errdefer device.releaseTexture(scene_depth_texture);

    // Create sampler.
    const effect_sampler = try device.createSampler(.{
        .min_filter = .nearest,
        .mag_filter = .nearest,
        .mipmap_mode = .nearest,
        .address_mode_u = .repeat,
        .address_mode_v = .repeat,
        .address_mode_w = .repeat,
    });

    // Prepare vertex buffers.
    const scene_vertex_buffer = try device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = scene_vertices_bytes.len,
    });
    errdefer device.releaseBuffer(scene_vertex_buffer);
    const effect_vertex_buffer = try device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = effect_vertices_bytes.len,
    });
    errdefer device.releaseBuffer(effect_vertex_buffer);

    // Create the index buffers.
    const scene_index_buffer = try device.createBuffer(.{
        .usage = .{ .index = true },
        .size = scene_indices_bytes.len,
    });
    errdefer device.releaseBuffer(scene_index_buffer);
    const effect_index_buffer = try device.createBuffer(.{
        .usage = .{ .index = true },
        .size = effect_indices_bytes.len,
    });
    errdefer device.releaseBuffer(effect_index_buffer);

    // Setup transfer buffer.
    const transfer_buffer_scene_vertex_data_off = 0;
    const transfer_buffer_scene_index_data_off = transfer_buffer_scene_vertex_data_off + scene_vertices_bytes.len;
    const transfer_buffer_effect_vertex_data_off = transfer_buffer_scene_index_data_off + scene_indices_bytes.len;
    const transfer_buffer_effect_index_data_off = transfer_buffer_effect_vertex_data_off + effect_vertices_bytes.len;
    const transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = @intCast(scene_vertices_bytes.len + scene_indices_bytes.len + effect_vertices_bytes.len + effect_indices_bytes.len),
    });
    defer device.releaseTransferBuffer(transfer_buffer);
    {
        const transfer_buffer_mapped = try device.mapTransferBuffer(transfer_buffer, false);
        defer device.unmapTransferBuffer(transfer_buffer);
        @memcpy(transfer_buffer_mapped[transfer_buffer_scene_vertex_data_off .. transfer_buffer_scene_vertex_data_off + scene_vertices_bytes.len], scene_vertices_bytes);
        @memcpy(transfer_buffer_mapped[transfer_buffer_scene_index_data_off .. transfer_buffer_scene_index_data_off + scene_indices_bytes.len], scene_indices_bytes);
        @memcpy(transfer_buffer_mapped[transfer_buffer_effect_vertex_data_off .. transfer_buffer_effect_vertex_data_off + effect_vertices_bytes.len], effect_vertices_bytes);
        @memcpy(transfer_buffer_mapped[transfer_buffer_effect_index_data_off .. transfer_buffer_effect_index_data_off + effect_indices_bytes.len], effect_indices_bytes);
    }

    // Upload transfer data.
    const cmd_buf = try device.acquireCommandBuffer();
    {
        const copy_pass = cmd_buf.beginCopyPass();
        defer copy_pass.end();
        copy_pass.uploadToBuffer(
            .{
                .transfer_buffer = transfer_buffer,
                .offset = transfer_buffer_scene_vertex_data_off,
            },
            .{
                .buffer = scene_vertex_buffer,
                .offset = 0,
                .size = scene_vertices_bytes.len,
            },
            false,
        );
        copy_pass.uploadToBuffer(
            .{
                .transfer_buffer = transfer_buffer,
                .offset = transfer_buffer_effect_vertex_data_off,
            },
            .{
                .buffer = effect_vertex_buffer,
                .offset = 0,
                .size = effect_vertices_bytes.len,
            },
            false,
        );
        copy_pass.uploadToBuffer(
            .{
                .transfer_buffer = transfer_buffer,
                .offset = transfer_buffer_scene_index_data_off,
            },
            .{
                .buffer = scene_index_buffer,
                .offset = 0,
                .size = scene_indices_bytes.len,
            },
            false,
        );
        copy_pass.uploadToBuffer(
            .{
                .transfer_buffer = transfer_buffer,
                .offset = transfer_buffer_effect_index_data_off,
            },
            .{
                .buffer = effect_index_buffer,
                .offset = 0,
                .size = effect_indices_bytes.len,
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
        .scene_pipeline = scene_pipeline,
        .scene_vertex_buffer = scene_vertex_buffer,
        .scene_index_buffer = scene_index_buffer,
        .scene_color_texture = scene_color_texture,
        .scene_depth_texture = scene_depth_texture,
        .effect_pipeline = effect_pipeline,
        .effect_vertex_buffer = effect_vertex_buffer,
        .effect_index_buffer = effect_index_buffer,
        .effect_sampler = effect_sampler,
        .scene_width = scene_width,
        .scene_height = scene_height,
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

        // Setup camera.
        const time = @as(f32, @floatFromInt(sdl3.timer.getMillisecondsSinceInit())) / sdl3.timer.milliseconds_per_second;
        const near_plane = 20;
        const far_plane = 60;
        const proj = Mat4.perspectiveFieldOfView(
            75 * std.math.pi / 180.0,
            @as(f32, @floatFromInt(app_state.scene_width)) / @as(f32, @floatFromInt(app_state.scene_height)),
            near_plane,
            far_plane,
        );
        const view = Mat4.lookAt(
            .{ @cos(time) * 30, 30, @sin(time) * 30 },
            .{ 0, 0, 0 },
            .{ 0, 1, 0 },
        );
        const proj_view = proj.mul(view);
        cmd_buf.pushVertexUniformData(0, std.mem.asBytes(&proj_view));
        cmd_buf.pushFragmentUniformData(0, std.mem.asBytes(&@as(@Vector(2, f32), .{ near_plane, far_plane })));

        // Start a render pass for the scene.
        {
            const render_pass = cmd_buf.beginRenderPass(&.{
                sdl3.gpu.ColorTargetInfo{
                    .texture = app_state.scene_color_texture,
                    .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
                    .load = .clear,
                },
            }, .{
                .texture = app_state.scene_depth_texture,
                .cycle = true,
                .clear_depth = 1,
                .clear_stencil = 0,
                .load = .clear,
                .store = .store,
                .stencil_load = .clear,
                .stencil_store = .store,
            });
            defer render_pass.end();
            render_pass.bindGraphicsPipeline(app_state.scene_pipeline);
            render_pass.bindVertexBuffers(
                0,
                &.{
                    .{ .buffer = app_state.scene_vertex_buffer, .offset = 0 },
                },
            );
            render_pass.bindIndexBuffer(
                .{ .buffer = app_state.scene_index_buffer, .offset = 0 },
                .indices_16bit,
            );
            render_pass.drawIndexedPrimitives(36, 1, 0, 0, 0);
        }

        // Start a render pass for the effect.
        {
            const render_pass = cmd_buf.beginRenderPass(&.{
                sdl3.gpu.ColorTargetInfo{
                    .texture = texture,
                    .clear_color = .{ .r = 0.2, .g = 0.5, .b = 0.4, .a = 1 },
                    .load = .clear,
                },
            }, null);
            defer render_pass.end();
            render_pass.bindGraphicsPipeline(app_state.effect_pipeline);
            render_pass.bindVertexBuffers(
                0,
                &.{
                    .{ .buffer = app_state.effect_vertex_buffer, .offset = 0 },
                },
            );
            render_pass.bindIndexBuffer(
                .{ .buffer = app_state.effect_index_buffer, .offset = 0 },
                .indices_16bit,
            );
            render_pass.bindFragmentSamplers(0, &.{
                .{ .texture = app_state.scene_color_texture, .sampler = app_state.effect_sampler },
                .{ .texture = app_state.scene_depth_texture, .sampler = app_state.effect_sampler },
            });
            render_pass.drawIndexedPrimitives(6, 1, 0, 0, 0);
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
        val.device.releaseSampler(val.effect_sampler);
        val.device.releaseBuffer(val.effect_index_buffer);
        val.device.releaseBuffer(val.effect_vertex_buffer);
        val.device.releaseGraphicsPipeline(val.effect_pipeline);
        val.device.releaseTexture(val.scene_depth_texture);
        val.device.releaseTexture(val.scene_color_texture);
        val.device.releaseBuffer(val.scene_index_buffer);
        val.device.releaseBuffer(val.scene_vertex_buffer);
        val.device.releaseGraphicsPipeline(val.scene_pipeline);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
