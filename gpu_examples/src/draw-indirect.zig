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

const vert_shader_source = @embedFile("positionColor.vert");
const vert_shader_name = "Position Color";
const frag_shader_source = @embedFile("solidColor.frag");
const frag_shader_name = "Solid Color";

const window_width = 640;
const window_height = 480;

const PositionColorVertex = packed struct {
    position: @Vector(3, f32),
    color: @Vector(4, u8),
};

const vertices = [_]PositionColorVertex{

    // Indexed indirect.
    .{ .position = .{ -1, -1, 0 }, .color = .{ 255, 0, 0, 255 } },
    .{ .position = .{ 1, -1, 0 }, .color = .{ 0, 255, 0, 255 } },
    .{ .position = .{ 1, 1, 0 }, .color = .{ 0, 0, 255, 255 } },
    .{ .position = .{ -1, 1, 0 }, .color = .{ 255, 255, 255, 255 } },

    // Indirect 1.
    .{ .position = .{ 1, -1, 0 }, .color = .{ 0, 255, 0, 255 } },
    .{ .position = .{ 0, -1, 0 }, .color = .{ 0, 0, 255, 255 } },
    .{ .position = .{ 0.5, 1, 0 }, .color = .{ 255, 0, 0, 255 } },

    // Indirect 2.
    .{ .position = .{ -1, -1, 0 }, .color = .{ 0, 255, 0, 255 } },
    .{ .position = .{ 0, -1, 0 }, .color = .{ 0, 0, 255, 255 } },
    .{ .position = .{ -0.5, 1, 0 }, .color = .{ 255, 0, 0, 255 } },
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

const indexed_draw_command = sdl3.gpu.IndexedIndirectDrawCommand{
    .num_indices = 6,
    .num_instances = 1,
};
const indexed_draw_command_bytes = std.mem.asBytes(&indexed_draw_command);

const draw_commands = [_]sdl3.gpu.IndirectDrawCommand{
    .{ .num_vertices = 3, .num_instances = 1, .first_vertex = 4 },
    .{ .num_vertices = 3, .num_instances = 1, .first_vertex = 7 },
};
const draw_commands_bytes = std.mem.asBytes(&draw_commands);

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    pipeline: sdl3.gpu.GraphicsPipeline,
    vertex_buffer: sdl3.gpu.Buffer,
    index_buffer: sdl3.gpu.Buffer,
    draw_buffer: sdl3.gpu.Buffer,
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
    const window = try sdl3.video.Window.init("Draw Indirect", window_width, window_height, .{});
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

    // Create the index buffer.
    const draw_buffer = try device.createBuffer(.{
        .usage = .{ .indirect = true },
        .size = indexed_draw_command_bytes.len + draw_commands_bytes.len,
    });
    errdefer device.releaseBuffer(draw_buffer);

    // Setup transfer buffer.
    const transfer_buffer_vertex_data_off = 0;
    const transfer_buffer_index_data_off = transfer_buffer_vertex_data_off + vertices_bytes.len;
    const transfer_buffer_indexed_draw_command_off = transfer_buffer_index_data_off + indices_bytes.len;
    const transfer_buffer_draw_commands_off = transfer_buffer_indexed_draw_command_off + indexed_draw_command_bytes.len;
    const transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = @intCast(vertices_bytes.len + indices_bytes.len + indexed_draw_command_bytes.len + draw_commands_bytes.len),
    });
    defer device.releaseTransferBuffer(transfer_buffer);
    {
        const transfer_buffer_mapped = try device.mapTransferBuffer(transfer_buffer, false);
        defer device.unmapTransferBuffer(transfer_buffer);
        @memcpy(transfer_buffer_mapped[transfer_buffer_vertex_data_off .. transfer_buffer_vertex_data_off + vertices_bytes.len], vertices_bytes);
        @memcpy(transfer_buffer_mapped[transfer_buffer_index_data_off .. transfer_buffer_index_data_off + indices_bytes.len], indices_bytes);
        @memcpy(transfer_buffer_mapped[transfer_buffer_indexed_draw_command_off .. transfer_buffer_indexed_draw_command_off + indexed_draw_command_bytes.len], indexed_draw_command_bytes);
        @memcpy(transfer_buffer_mapped[transfer_buffer_draw_commands_off .. transfer_buffer_draw_commands_off + draw_commands_bytes.len], draw_commands_bytes);
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
        copy_pass.uploadToBuffer(
            .{
                .transfer_buffer = transfer_buffer,
                .offset = transfer_buffer_indexed_draw_command_off,
            },
            .{
                .buffer = draw_buffer,
                .offset = 0,
                .size = indexed_draw_command_bytes.len + draw_commands_bytes.len,
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
        .draw_buffer = draw_buffer,
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
        render_pass.drawIndexedPrimitivesIndirect(app_state.draw_buffer, 0, 1);
        render_pass.drawPrimitivesIndirect(app_state.draw_buffer, indexed_draw_command_bytes.len, 2);
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
        val.device.releaseBuffer(val.draw_buffer);
        val.device.releaseBuffer(val.index_buffer);
        val.device.releaseBuffer(val.vertex_buffer);
        val.device.releaseGraphicsPipeline(val.pipeline);
        val.device.releaseWindow(val.window);
        val.window.deinit();
        val.device.deinit();
        allocator.destroy(val);
    }
}
