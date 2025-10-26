const std = @import("std");

const ShaderFormat = enum {
    vertex,
    fragment,
    compute,
};

const OutputFormat = enum {
    dxbc,
    dxil,
    msl,
    spirv,
};

fn shadercross(b: *std.Build, sdl3: *std.Build.Dependency) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "shadercross",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .link_libc = true,
        }),
    });
    exe.root_module.linkLibrary(sdl3.builder.dependency("sdl", .{ .target = b.graph.host }).artifact("SDL3"));

    const upstream = sdl3.builder.dependency("sdl_shadercross", .{ .target = b.graph.host });
    exe.root_module.addIncludePath(upstream.path("include"));
    exe.root_module.addIncludePath(upstream.path("src"));

    exe.root_module.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = &.{
            "SDL_shadercross.c",
            "cli.c",
        },
        .flags = &.{
            "-DDXC=1",
        },
    });

    exe.installHeadersDirectory(upstream.path("include"), "", .{});

    const spirv_headers = sdl3.builder.dependency("spirv_headers", .{
        .target = b.graph.host,
    });
    const spirv_cross = sdl3.builder.dependency("spirv_cross", .{
        .target = b.graph.host,
        .optimize = .ReleaseFast, // There is a C bug in spirv-cross upstream! Ignore undefined behavior for now.
        .spv_cross_reflect = true,
        .spv_cross_cpp = false,
    });
    exe.linkLibrary(spirv_cross.artifact("spirv-cross-c"));
    exe.addIncludePath(spirv_headers.path("include/spirv/1.2/"));

    return exe;
}

fn setupShader(
    b: *std.Build,
    module: *std.Build.Module,
    name: []const u8,
    shadercross_exe: *std.Build.Step.Compile,
    debug: bool,
    output_format: OutputFormat,
) !void {
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

    // Optimize SPIR-V if possible.
    if (b.findProgram(&.{"spirv-opt"}, &.{})) |spirv_opt| {

        // Remove duplicate type definitions that might be done by inline assembly.
        const spirv_fix = b.addSystemCommand(&.{ spirv_opt, "--remove-duplicates", "--skip-validation" });
        spirv_fix.addFileArg(obj.getEmittedBin());
        spirv_fix.addArg("-o");
        const fixed_spirv = spirv_fix.addOutputFileArg(b.fmt("{s}-fixed.spv", .{name}));

        // Optimize the SPIRV.
        const spirv_opt_cmd = b.addSystemCommand(&.{ spirv_opt, "-O" });
        spirv_opt_cmd.addFileArg(fixed_spirv);
        spirv_opt_cmd.addArg("-o");
        shader_out = spirv_opt_cmd.addOutputFileArg(b.fmt("{s}-opt.spv", .{name}));
    } else |err| switch (err) {
        error.FileNotFound => std.debug.print("spirv-opt not found, shader output will be unoptimized!\n", .{}),
    }

    if (output_format != .spirv) {
        const name_ext = name[std.mem.indexOf(u8, name, ".").?..];
        const format: ShaderFormat = if (std.mem.eql(u8, name_ext, ".vert"))
            .vertex
        else if (std.mem.eql(u8, name_ext, ".frag"))
            .fragment
        else
            .compute;
        const run_shadercross = b.addRunArtifact(shadercross_exe);
        const upper = try std.ascii.allocUpperString(b.allocator, @tagName(output_format));
        run_shadercross.addFileArg(shader_out);
        run_shadercross.addArgs(&.{ "--source", "SPIRV", "--entrypoint", "main", "--stage", @tagName(format), "--dest", upper });
        if (debug)
            run_shadercross.addArg("--debug");
        run_shadercross.addArg("--output");
        shader_out = run_shadercross.addOutputFileArg(b.fmt("{s}.{s}", .{ name, @tagName(output_format) }));
    }
    module.addAnonymousImport(name, .{ .root_source_file = shader_out });
}

fn buildShaders(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    shadercross_exe: *std.Build.Step.Compile,
    debug: bool,
    output_format: OutputFormat,
) !void {
    var dir = (try std.fs.openDirAbsolute(b.path("shaders").getPath(b), .{ .iterate = true }));
    defer dir.close();
    var dir_iterator = dir.iterate();
    while (try dir_iterator.next()) |file| {
        if (file.kind == .file) {
            const extension = ".zig";
            if (!std.mem.endsWith(u8, file.name, extension))
                continue;
            try setupShader(
                b,
                exe.root_module,
                file.name[0..(file.name.len - extension.len)],
                shadercross_exe,
                debug,
                output_format,
            );
        }
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "template",
        .root_module = exe_mod,
    });

    const sdl3 = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
        .callbacks = true,
        .ext_image = true,
    });
    exe.root_module.addImport("sdl3", sdl3.module("sdl3"));
    const shadercross_exe = shadercross(
        b,
        sdl3,
    );
    const options = b.addOptions();
    const gpu_debug = b.option(bool, "gpu_debug", "If to have enable GPU debug mode") orelse false;
    const shader_debug = b.option(bool, "shader_debug", "If to have debug info in the shaders") orelse false;
    const shader_format = b.option(OutputFormat, "shader_format", "Output shader format") orelse .spirv;
    options.addOption(bool, "gpu_debug", gpu_debug);
    options.addOption(bool, "shader_debug", shader_debug);
    options.addOption(OutputFormat, "shader_format", shader_format);
    try buildShaders(
        b,
        exe,
        shadercross_exe,
        shader_debug,
        shader_format,
    );
    b.installArtifact(exe);
    exe.root_module.addOptions("options", options);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
