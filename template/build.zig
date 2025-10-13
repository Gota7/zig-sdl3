const std = @import("std");
const zemscripten = @import("zemscripten");

fn buildBin(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !void {
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

fn buildWeb(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !void {
    const activateEmsdk = zemscripten.activateEmsdkStep(b);
    b.default_step.dependOn(activateEmsdk);

    const wasm = b.addLibrary(.{
        .name = "zig_sdl3_cross_template",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main-web.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });

    const zemscripten_dep = b.dependency("zemscripten", .{});
    wasm.root_module.addImport("zemscripten", zemscripten_dep.module("root"));

    const emsdk_dep = b.dependency("emsdk", .{});
    const emsdk_sysroot_include_path = emsdk_dep.path("upstream/emscripten/cache/sysroot/include");
    // sdl3.artifact("SDL3").addSystemIncludePath(emsdk_sysroot_include_path);

    const sdl3 = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
        .callbacks = true,
        .ext_image = true,
        .sdl_system_include_path = emsdk_sysroot_include_path,
    });
    wasm.root_module.addImport("sdl3", sdl3.module("sdl3"));

    const sysroot_include = b.pathJoin(&.{ b.sysroot.?, "include" });
    var dir = std.fs.openDirAbsolute(sysroot_include, .{ .access_sub_paths = true, .no_follow = true }) catch @panic("No emscripten cache. Generate it!");
    dir.close();
    wasm.addSystemIncludePath(.{ .cwd_relative = sysroot_include });

    const emcc_flags = zemscripten.emccDefaultFlags(b.allocator, .{
        .optimize = optimize,
        .fsanitize = true,
    });

    var emcc_settings = zemscripten.emccDefaultSettings(b.allocator, .{
        .optimize = optimize,
    });
    try emcc_settings.put("ALLOW_MEMORY_GROWTH", "1");
    emcc_settings.put("USE_SDL", "3") catch unreachable;

    const emcc_step = zemscripten.emccStep(
        b,
        wasm,
        .{
            .optimize = optimize,
            .flags = emcc_flags, // Pass the modified flags
            .settings = emcc_settings,
            .use_preload_plugins = true,
            .embed_paths = &.{},
            .preload_paths = &.{},
            .install_dir = .{ .custom = "web" },
            .shell_file_path = b.path("src/html/shell.html"),
        },
    );

    b.getInstallStep().dependOn(emcc_step);

    var run_emrun_step = b.step("emrun", "Run the WebAssembly app using emrun");

    const emrun_cmd = b.addSystemCommand(&.{
        "emrun",
        "--no_browser",
        "--port",
        "8080",
        wasm.name,
    });

    emrun_cmd.step.dependOn(b.getInstallStep());

    run_emrun_step.dependOn(&emrun_cmd.step);

    const run_step = b.step("run", "Run the app (via emrun)");
    run_step.dependOn(run_emrun_step);

    if (b.args) |args| {
        emrun_cmd.addArgs(args);
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const os = target.result.os.tag;
    if (os == .emscripten) {
        try buildWeb(b, target, optimize);
    } else {
        try buildBin(b, target, optimize);
    }
}
