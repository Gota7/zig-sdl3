const std = @import("std");
const zig = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const cfg = std.Build.TestOptions{
        .name = "zig-sdl3",
        .target = target,
        .optimize = b.standardOptimizeOption(.{}),
        .root_source_file = b.path("src/sdl3.zig"),
        .version = .{
            .major = 0,
            .minor = 1,
            .patch = 0,
        },
    };
    _ = generateBindings(b, cfg);
    const sdl3 = b.addModule("sdl3", .{ .root_source_file = cfg.root_source_file, .target = target });
    const main_callbacks = b.option(bool, "callbacks", "Enable SDL callbacks rather than use a main function") orelse false;
    if (main_callbacks)
        sdl3.addCSourceFile(.{ .file = b.path("main_callbacks.c") });
    const extension_options = b.addOptions();
    const ext_image = b.option(bool, "ext_image", "Enable SDL_image extension") orelse false;
    extension_options.addOption(bool, "image", ext_image);
    sdl3.addOptions("extension_options", extension_options);
    _ = setupTest(b, cfg, extension_options, ext_image);
    // _ = try setupExamples(b, sdl3, cfg);
    _ = try runExample(b, sdl3, cfg, ext_image);

    if (b.option([]const u8, "sdl3_include_path", "Path to where root SDL3 include directory is located")) |p| sdl3.addSystemIncludePath(.{ .cwd_relative = p });
    if (b.option([]const u8, "sdl3_image_include_path", "Path to includes where SDL3_image directory is located")) |p| sdl3.addSystemIncludePath(.{ .cwd_relative = p });
    if (target.result.os.tag == .windows) {
        // SDL3 must be either compiled by yourself or precompiled files downloaded & headers (include) dir extracted:
        // https://github.com/libsdl-org/SDL/releases/tag/preview-3.1.6
        // https://github.com/libsdl-org/SDL_image/releases/tag/preview-3.1.0
        const sdl3_dll_path = b.option([]const u8, "sdl3_dll_path", "Path to directory where SDL3.dll is located");
        if (sdl3_dll_path) |p| {
            b.installBinFile(b.pathJoin(&.{ p, "SDL3.dll" }), "SDL3.dll");
            sdl3.addObjectFile(.{ .cwd_relative = b.pathJoin(&.{ p, "SDL3.dll" }) });
        }
    } else {
        sdl3.linkSystemLibrary("SDL3", .{ .needed = true });
    }
}

pub fn linkTarget(b: *std.Build, target: *std.Build.Step.Compile, image: bool) void {
    // target.addSystemIncludePath(b.path("/usr/local/include"));
    _ = b;
    if (image)
        target.linkSystemLibrary("SDL3_image");
    target.linkSystemLibrary("m");
    target.linkLibC();
}

pub fn generateBindings(b: *std.Build, cfg: std.Build.TestOptions) *std.Build.Step {
    const exp = b.step("bindings", "Generate bindings for SDL3");
    const exe = b.addExecutable(.{
        .name = "generate-bindings",
        .target = cfg.target orelse b.standardTargetOptions(.{}),
        .optimize = cfg.optimize,
        .root_source_file = b.path("generate.zig"),
        .version = cfg.version,
    });
    const ymlz = b.dependency("ymlz", .{});
    exe.root_module.addImport("ymlz", ymlz.module("root"));
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    exp.dependOn(&run.step);
    return exp;
}

pub fn setupExample(b: *std.Build, sdl3: *std.Build.Module, cfg: std.Build.TestOptions, name: []const u8, ext_image: bool) !*std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .target = cfg.target orelse b.standardTargetOptions(.{}),
        .optimize = cfg.optimize,
        .root_source_file = b.path(try std.fmt.allocPrint(b.allocator, "examples/{s}.zig", .{name})),
        .version = cfg.version,
    });
    exe.root_module.addImport("sdl3", sdl3);
    linkTarget(b, exe, ext_image);
    b.installArtifact(exe);
    return exe;
}

pub fn runExample(b: *std.Build, sdl3: *std.Build.Module, cfg: std.Build.TestOptions, ext_image: bool) !void {
    const run_example: ?[]const u8 = b.option([]const u8, "example", "The example name for running an example") orelse null;
    const run = b.step("run", "Run an example with -Dexample=<example_name> option");
    if (run_example) |example| {
        const run_art = b.addRunArtifact(try setupExample(b, sdl3, cfg, example, ext_image));
        run_art.step.dependOn(b.getInstallStep());
        run.dependOn(&run_art.step);
    }
}

pub fn setupExamples(b: *std.Build, sdl3: *std.Build.Module, cfg: std.Build.TestOptions) !*std.Build.Step {
    const exp = b.step("examples", "Build all examples");
    const examples_dir = b.path("examples");
    var dir = (try std.fs.openDirAbsolute(examples_dir.getPath(b), .{ .iterate = true }));
    defer dir.close();
    var dir_iterator = try dir.walk(b.allocator);
    defer dir_iterator.deinit();
    while (try dir_iterator.next()) |file| {
        if (file.kind == .file and std.mem.endsWith(u8, file.basename, ".zig")) {
            _ = try setupExample(b, sdl3, cfg, file.basename[0 .. file.basename.len - 4]);
        }
    }
    exp.dependOn(b.getInstallStep());
    return exp;
}

pub fn setupTest(b: *std.Build, cfg: std.Build.TestOptions, extension_options: *std.Build.Step.Options, ext_image: bool) *std.Build.Step.Compile {
    const tst = b.addTest(cfg);
    linkTarget(b, tst, ext_image);
    tst.root_module.addOptions("extension_options", extension_options);
    const tst_run = b.addRunArtifact(tst);
    const tst_step = b.step("test", "Run all tests");
    tst_step.dependOn(&tst_run.step);
    return tst;
}
