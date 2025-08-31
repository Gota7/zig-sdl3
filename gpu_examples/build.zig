const std = @import("std");

// TODO: USE!!!
const ShaderFormat = enum {
    hlsl,
    glsl,
    zig,
};

fn buildExample(b: *std.Build, sdl3: *std.Build.Module, options: *std.Build.Step.Options, name: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !*std.Build.Step.Compile {
    const exe_mod = b.createModule(.{
        .root_source_file = b.path(try std.fmt.allocPrint(b.allocator, "src/{s}.zig", .{name})),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = exe_mod,
    });
    exe.root_module.addImport("sdl3", sdl3);
    exe.root_module.addOptions("options", options);
    b.installArtifact(exe);
    return exe;
}

pub fn runExample(b: *std.Build, sdl3: *std.Build.Module, options: *std.Build.Step.Options, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !void {
    const run_example: ?[]const u8 = b.option([]const u8, "example", "The example name for running an example") orelse null;
    const run = b.step("run", "Run an example with -Dexample=<example_name> option");
    if (run_example) |example| {
        const run_art = b.addRunArtifact(try buildExample(b, sdl3, options, example, target, optimize));
        run_art.step.dependOn(b.getInstallStep());
        run.dependOn(&run_art.step);
    }
}

pub fn setupExamples(b: *std.Build, sdl3: *std.Build.Module, options: *std.Build.Step.Options, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !void {
    const exp = b.step("examples", "Build all examples");
    const examples_dir = b.path("src");
    var dir = (try std.fs.openDirAbsolute(examples_dir.getPath(b), .{ .iterate = true }));
    defer dir.close();
    var dir_iterator = try dir.walk(b.allocator);
    defer dir_iterator.deinit();
    while (try dir_iterator.next()) |file| {
        if (file.kind == .file and std.mem.endsWith(u8, file.basename, ".zig")) {
            _ = try buildExample(b, sdl3, options, file.basename[0 .. file.basename.len - 4], target, optimize);
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
    options.addOption(bool, "spirv", true); // TODO!!!
    try setupExamples(b, sdl3_mod, options, target, optimize);
    try runExample(b, sdl3_mod, options, target, optimize);
}
