const std = @import("std");

const depth_overrides = [_][]const u8{
    "solidColorDepth.frag",
};

const ShaderFormat = enum {
    glsl,
    hlsl,
    zig,
    hlsl_runtime,
};

fn setupShader(
    b: *std.Build,
    module: *std.Build.Module,
    name: []const u8,
    format: ShaderFormat,
) !void {
    // Compute shaders not possible for zig atm. See `shaders/basic-compute.zig` for more info.
    const suffix = name[std.mem.lastIndexOf(u8, name, ".").? + 1 ..];
    const actual_format = if (format == .zig and std.mem.eql(u8, suffix, "comp")) .hlsl else format;
    switch (actual_format) {
        .glsl, .hlsl => {
            const glslang = b.findProgram(&.{"glslang"}, &.{}) catch @panic("glslang not found, can not compile GLSL shaders");
            const glslang_cmd = b.addSystemCommand(&.{ glslang, "-V100", "-e", "main", "-S" });
            glslang_cmd.addArg(suffix);
            if (actual_format == .hlsl)
                glslang_cmd.addArg("-D");
            glslang_cmd.addFileArg(b.path(b.fmt("shaders/{s}.{s}", .{ name, if (actual_format == .glsl) "glsl" else "hlsl" })));
            glslang_cmd.addArg("-o");
            const glslang_cmd_out = glslang_cmd.addOutputFileArg(b.fmt("{s}.spv", .{name}));

            module.addAnonymousImport(name, .{ .root_source_file = glslang_cmd_out });
        },
        .hlsl_runtime => module.addAnonymousImport(name, .{ .root_source_file = b.path(b.fmt("shaders/{s}.hlsl", .{name})) }),
        .zig => {
            const obj = b.addObject(.{
                .name = name,
                .root_module = b.addModule(name, .{
                    .root_source_file = b.path(b.fmt("shaders/{s}.zig", .{name})),
                    .target = b.resolveTargetQuery(.{
                        .cpu_arch = .spirv64,
                        .cpu_model = .{ .explicit = &std.Target.spirv.cpu.vulkan_v1_2 },
                        .cpu_features_add = std.Target.spirv.featureSet(&.{}),
                        .os_tag = .vulkan,
                        .ofmt = .spirv,
                    }),
                }),
                .use_llvm = false,
                .use_lld = false,
            });
            var shader_out = obj.getEmittedBin();

            if (b.findProgram(&.{"spirv-opt"}, &.{})) |spirv_opt| {

                // Remove duplicate type definitions that might be done by inline assembly.
                const spirv_fix = b.addSystemCommand(&.{ spirv_opt, "--remove-duplicates", "--skip-validation" });
                spirv_fix.addFileArg(obj.getEmittedBin());
                spirv_fix.addArg("-o");
                var fixed_spirv = spirv_fix.addOutputFileArg(b.fmt("{s}-fixed.spv", .{name}));

                // Handle depth overrides.
                var depth_override = false;
                for (depth_overrides) |val| {
                    if (std.mem.eql(u8, val, name)) {
                        depth_override = true;
                        break;
                    }
                }
                if (depth_override) {

                    // Disassemble into SPIRV assembly.
                    const spirv_dis = try b.findProgram(&.{"spirv-dis"}, &.{});
                    const spirv_dis_cmd = b.addSystemCommand(&.{spirv_dis});
                    spirv_dis_cmd.addFileArg(fixed_spirv);
                    spirv_dis_cmd.addArg("-o");
                    const spirv_dis_out = spirv_dis_cmd.addOutputFileArg(b.fmt("{s}.spvasm", .{name}));

                    // Modify the execution mode using a custom build tool.
                    const spirv_execution_mode = b.addExecutable(.{
                        .name = "spirv-execution-mode",
                        .root_module = b.createModule(.{
                            .root_source_file = b.path("build_tools/spirv_execution_mode.zig"),
                            .target = b.graph.host,
                        }),
                    });
                    const spirv_execution_mode_cmd = b.addRunArtifact(spirv_execution_mode);
                    spirv_execution_mode_cmd.addFileArg(spirv_dis_out);
                    const execution_mode_changed_spirv = spirv_execution_mode_cmd.addOutputFileArg(b.fmt("{s}-execution-mode-fixed.spvasm", .{name}));
                    spirv_execution_mode_cmd.addArg("DepthReplacing");
                    // TODO: ALLOW COMPUTE SHADERS!!!

                    // Reassemble updated assembly.
                    const spirv_as = try b.findProgram(&.{"spirv-as"}, &.{});
                    const spirv_as_cmd = b.addSystemCommand(&.{spirv_as});
                    spirv_as_cmd.addFileArg(execution_mode_changed_spirv);
                    spirv_as_cmd.addArg("-o");
                    fixed_spirv = spirv_as_cmd.addOutputFileArg(b.fmt("{s}-execution-mode-fixed.spv", .{name}));
                }

                // Optimize the SPIRV.
                const spirv_opt_cmd = b.addSystemCommand(&.{ spirv_opt, "-O" });
                spirv_opt_cmd.addFileArg(fixed_spirv);
                spirv_opt_cmd.addArg("-o");
                shader_out = spirv_opt_cmd.addOutputFileArg(b.fmt("{s}-opt.spv", .{name}));
            } else |err| switch (err) {
                error.FileNotFound => std.debug.print("spirv-opt not found, shader output will be unoptimized!\n", .{}),
            }

            module.addAnonymousImport(name, .{ .root_source_file = shader_out });
        },
    }
}

fn buildExample(
    b: *std.Build,
    sdl3: *std.Build.Module,
    format: ShaderFormat,
    options: *std.Build.Step.Options,
    name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Step.Compile {
    const exe_mod = b.createModule(.{
        .root_source_file = b.path(b.fmt("src/{s}.zig", .{name})),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = exe_mod,
    });

    var dir = (try std.fs.openDirAbsolute(b.path("shaders").getPath(b), .{ .iterate = true }));
    defer dir.close();
    var dir_iterator = try dir.walk(b.allocator);
    defer dir_iterator.deinit();
    while (try dir_iterator.next()) |file| {
        if (file.kind == .file) {
            const extension = switch (format) {
                .glsl => ".glsl",
                .hlsl => ".hlsl",
                .zig => ".zig",
                .hlsl_runtime => ".hlsl",
            };
            if (!std.mem.endsWith(u8, file.basename, extension))
                continue;
            try setupShader(b, exe.root_module, file.basename[0..(file.basename.len - extension.len)], format);
        }
    }

    exe.root_module.addImport("sdl3", sdl3);
    exe.root_module.addOptions("options", options);
    b.installArtifact(exe);
    return exe;
}

pub fn runExample(
    b: *std.Build,
    sdl3: *std.Build.Module,
    format: ShaderFormat,
    options: *std.Build.Step.Options,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    const run_example: ?[]const u8 = b.option([]const u8, "example", "The example name for running an example") orelse null;
    const run = b.step("run", "Run an example with -Dexample=<example_name> option");
    if (run_example) |example| {
        const run_art = b.addRunArtifact(try buildExample(b, sdl3, format, options, example, target, optimize));
        run_art.step.dependOn(b.getInstallStep());
        run.dependOn(&run_art.step);
    }
}

pub fn setupExamples(
    b: *std.Build,
    sdl3: *std.Build.Module,
    format: ShaderFormat,
    options: *std.Build.Step.Options,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    const exp = b.step("examples", "Build all examples");
    const examples_dir = b.path("src");
    var dir = (try std.fs.openDirAbsolute(examples_dir.getPath(b), .{ .iterate = true }));
    defer dir.close();
    var dir_iterator = try dir.walk(b.allocator);
    defer dir_iterator.deinit();
    while (try dir_iterator.next()) |file| {
        if (file.kind == .file and std.mem.endsWith(u8, file.basename, ".zig")) {
            _ = try buildExample(b, sdl3, format, options, file.basename[0 .. file.basename.len - 4], target, optimize);
        }
    }
    exp.dependOn(b.getInstallStep());
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl3 = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
        .callbacks = true,
        .ext_shadercross = true,
    });
    const sdl3_mod = sdl3.module("sdl3");
    const options = b.addOptions();

    const format = b.option(ShaderFormat, "shader_format", "Shader format to use") orelse .zig;
    options.addOption(bool, "spirv", format != .hlsl_runtime);
    options.addOption(bool, "gpu_debug", b.option(bool, "gpu_debug", "Enable GPU debugging functionality") orelse false);
    try setupExamples(b, sdl3_mod, format, options, target, optimize);
    try runExample(b, sdl3_mod, format, options, target, optimize);
}
