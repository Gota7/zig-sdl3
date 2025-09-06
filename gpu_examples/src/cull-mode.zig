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

const vertices: struct {
    cw: [3]PositionColorVertex = .{
        .{ .position = .{ -1, -1, 0 }, .color = .{ 255, 0, 0, 255 } },
        .{ .position = .{ 1, -1, 0 }, .color = .{ 0, 255, 0, 255 } },
        .{ .position = .{ 0, 1, 0 }, .color = .{ 0, 0, 255, 255 } },
    },
    ccw: [3]PositionColorVertex = .{
        .{ .position = .{ 0, 1, 0 }, .color = .{ 255, 0, 0, 255 } },
        .{ .position = .{ 1, -1, 0 }, .color = .{ 0, 255, 0, 255 } },
        .{ .position = .{ -1, -1, 0 }, .color = .{ 0, 0, 255, 255 } },
    },
} = .{};
const vertices_bytes = std.mem.asBytes(&vertices);
const vertices_cw_offset = @offsetOf(@TypeOf(vertices), "cw");
const vertices_ccw_offset = @offsetOf(@TypeOf(vertices), "ccw");
const vertices_cw_size = @sizeOf(@FieldType(@TypeOf(vertices), "cw"));
const vertices_ccw_size = @sizeOf(@FieldType(@TypeOf(vertices), "ccw"));

const mode_names = [_][:0]const u8{
    "CW_CullNone",
    "CW_CullFront",
    "CW_CullBack",
    "CCW_CullNone",
    "CCW_CullFront",
    "CCW_CullBack",
};

const AppState = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    pipelines: [mode_names.len]sdl3.gpu.GraphicsPipeline,
    vertex_buffer_cw: sdl3.gpu.Buffer,
    vertex_buffer_ccw: sdl3.gpu.Buffer,
    curr_mode: usize = 0,
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
    const window = try sdl3.video.Window.init("Cull Mode", window_width, window_height, .{});
    errdefer window.deinit();
    try device.claimWindow(window);

    // Prepare pipelines.
    const vertex_shader = try loadGraphicsShader(device, vert_shader_name, vert_shader_source, .vertex);
    defer device.releaseShader(vertex_shader);
    const fragment_shader = try loadGraphicsShader(device, frag_shader_name, frag_shader_source, .fragment);
    defer device.releaseShader(fragment_shader);
    var pipeline_create_info = sdl3.gpu.GraphicsPipelineCreateInfo{
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

    // Prepare vertex buffers.
    const vertex_buffer_cw = try device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = vertices_cw_size,
    });
    errdefer device.releaseBuffer(vertex_buffer_cw);
    const vertex_buffer_ccw = try device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = vertices_ccw_size,
    });
    errdefer device.releaseBuffer(vertex_buffer_ccw);

    // Setup transfer buffer.
    const transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = vertices_bytes.len,
    });
    defer device.releaseTransferBuffer(transfer_buffer);
    {
        const transfer_buffer_mapped = try device.mapTransferBuffer(transfer_buffer, false);
        defer device.unmapTransferBuffer(transfer_buffer);
        @memcpy(transfer_buffer_mapped, vertices_bytes);
    }

    // Upload transfer data.
    const cmd_buf = try device.acquireCommandBuffer();
    {
        const copy_pass = cmd_buf.beginCopyPass();
        defer copy_pass.end();
        copy_pass.uploadToBuffer(
            .{
                .transfer_buffer = transfer_buffer,
                .offset = vertices_cw_offset,
            },
            .{
                .buffer = vertex_buffer_cw,
                .offset = 0,
                .size = vertices_cw_size,
            },
            false,
        );
        copy_pass.uploadToBuffer(
            .{
                .transfer_buffer = transfer_buffer,
                .offset = vertices_ccw_offset,
            },
            .{
                .buffer = vertex_buffer_ccw,
                .offset = 0,
                .size = vertices_ccw_size,
            },
            false,
        );
    }
    try cmd_buf.submit();

    // Prepare app state.
    const state = try allocator.create(AppState);
    errdefer allocator.destroy(state);

    try sdl3.log.log("Press Left/Right to switch between modes", .{});
    try sdl3.log.log("Current Mode: {s}", .{mode_names[0]});

    // Prevent potential errdefer leaks by making the pipelines here.
    var pipelines: [mode_names.len]sdl3.gpu.GraphicsPipeline = undefined;
    for (0..pipelines.len) |i| {
        pipeline_create_info.rasterizer_state.cull_mode = @enumFromInt(i % 3);
        pipeline_create_info.rasterizer_state.front_face = if (i > 2) .clockwise else .counter_clockwise;
        pipelines[i] = try device.createGraphicsPipeline(pipeline_create_info);
        errdefer device.releaseGraphicsPipeline(pipelines[i]); // TODO: Prevent possible leak here?
    }

    // Set state.
    state.* = .{
        .device = device,
        .window = window,
        .pipelines = pipelines,
        .vertex_buffer_cw = vertex_buffer_cw,
        .vertex_buffer_ccw = vertex_buffer_ccw,
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

        // Choose the pipeline currently set.
        render_pass.bindGraphicsPipeline(app_state.pipelines[app_state.curr_mode]);

        // Bind the vertex buffers then draw the primitives.
        render_pass.setViewport(.{ .region = .{ .x = 0, .y = 0, .w = 320, .h = 480 } });
        render_pass.bindVertexBuffers(0, &.{
            .{ .buffer = app_state.vertex_buffer_cw, .offset = 0 },
        });
        render_pass.drawPrimitives(3, 1, 0, 0);
        render_pass.setViewport(.{ .region = .{ .x = 320, .y = 0, .w = 320, .h = 480 } });
        render_pass.bindVertexBuffers(0, &.{
            .{ .buffer = app_state.vertex_buffer_ccw, .offset = 0 },
        });
        render_pass.drawPrimitives(3, 1, 0, 0);
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
            if (!key.repeat)
                if (key.key) |val| switch (val) {
                    .left => {
                        if (app_state.curr_mode == 0) {
                            app_state.curr_mode = app_state.pipelines.len - 1;
                        } else app_state.curr_mode -= 1;
                        try sdl3.log.log("Current Mode: {s}", .{mode_names[app_state.curr_mode]});
                    },
                    .right => {
                        if (app_state.curr_mode >= app_state.pipelines.len - 1) {
                            app_state.curr_mode = 0;
                        } else app_state.curr_mode += 1;
                        try sdl3.log.log("Current Mode: {s}", .{mode_names[app_state.curr_mode]});
                    },
                    else => {},
                };
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
        val.device.releaseBuffer(val.vertex_buffer_ccw);
        val.device.releaseBuffer(val.vertex_buffer_cw);
        for (val.pipelines) |pipeline| {
            val.device.releaseGraphicsPipeline(pipeline);
        }
        val.device.deinit();
        val.window.deinit();
        allocator.destroy(val);
    }
}
