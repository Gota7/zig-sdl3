const std = @import("std");

fn shadercross(b: *std.Build, sdl_dep_lib: *std.Build.Step.Compile) *std.Build.Step.Compile {
    const upstream = b.lazyDependency("sdl_shadercross", .{}) orelse return;

    const exe = b.addExecutable(.{
        .name = "shadercross",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .link_libc = true,
        }),
    });
    exe.root_module.linkLibrary(sdl_dep_lib);

    exe.root_module.addIncludePath(upstream.path("include"));
    exe.root_module.addIncludePath(upstream.path("src"));

    exe.root_module.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = &.{
            "SDL_shadercross.c",
            "cli.c",
        },
    });

    exe.installHeadersDirectory(upstream.path("include"), "", .{});

    const spirv_headers = b.dependency("spirv_headers", .{});
    const spirv_cross = b.dependency("spirv_cross", .{
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
) !void {}

fn buildShaders(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
) void {
    var dir = (try std.fs.openDirAbsolute(b.path("shaders").getPath(b), .{ .iterate = true }));
    defer dir.close();
    var dir_iterator = try dir.walk(b.allocator);
    defer dir_iterator.deinit();
    while (try dir_iterator.next()) |file| {
        if (file.kind == .file) {
            const extension = ".hlsl";
            if (!std.mem.endsWith(u8, file.basename, extension))
                continue;
            try setupShader(b, exe.root_module, file.basename[0..(file.basename.len - extension.len)], format);
        }
    }
}

pub fn build(b: *std.Build) void {
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
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
