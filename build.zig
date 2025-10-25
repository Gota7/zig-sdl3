const std = @import("std");
const zig = @import("builtin");

const image = @import("build/image.zig");
const net = @import("build/net.zig");
const ttf = @import("build/ttf.zig");

const ExampleOptions = struct {
    ext_image: bool,
    ext_net: bool,
    ext_ttf: bool,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cfg: Config = .{
        .name = "zig-sdl3",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/sdl3.zig"),
        .version = .{
            .major = 0,
            .minor = 1,
            .patch = 5,
        },
    };

    // C SDL options.
    const c_sdl_preferred_linkage = b.option(
        std.builtin.LinkMode,
        "c_sdl_preferred_linkage",
        "Prefer building statically or dynamically linked libraries (default: static)",
    ) orelse .static;
    const c_sdl_strip = b.option(
        bool,
        "c_sdl_strip",
        "Strip debug symbols (default: varies)",
    ) orelse (optimize == .ReleaseSmall);
    const c_sdl_sanitize_c = b.option(
        std.zig.SanitizeC,
        "c_sdl_sanitize_c",
        "Detect C undefined behavior (default: trap)",
    ) orelse .trap;
    const c_sdl_lto = b.option(
        std.zig.LtoMode,
        "c_sdl_lto",
        "Perform link time optimization (default: false)",
    ) orelse .none;
    const c_sdl_emscripten_pthreads = b.option(
        bool,
        "c_sdl_emscripten_pthreads",
        "Build with pthreads support when targeting Emscripten (default: false)",
    ) orelse false;
    const c_sdl_install_build_config_h = b.option(
        bool,
        "c_sdl_install_build_config_h",
        "Additionally install 'SDL_build_config.h' when installing SDL (default: false)",
    ) orelse false;
    const sdl_system_include_path = b.option(
        std.Build.LazyPath,
        "sdl_system_include_path",
        "System include path for SDL",
    );
    const sdl_sysroot_path = b.option(
        std.Build.LazyPath,
        "sdl_sysroot_path",
        "System include path for SDL",
    );

    if (sdl_sysroot_path) |val| {
        b.sysroot = val.getPath(b);
    }

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = c_sdl_preferred_linkage,
        .strip = c_sdl_strip,
        .sanitize_c = c_sdl_sanitize_c,
        .lto = c_sdl_lto,
        .emscripten_pthreads = c_sdl_emscripten_pthreads,
        .install_build_config_h = c_sdl_install_build_config_h,
    });

    const sdl_dep_lib = sdl_dep.artifact("SDL3");
    if (sdl_system_include_path) |val|
        sdl_dep_lib.addSystemIncludePath(val);
    b.installArtifact(sdl_dep_lib);

    // SDL options.
    const options = b.addOptions();
    const main_callbacks = b.option(bool, "callbacks", "Enable SDL callbacks rather than use a main function") orelse false;
    options.addOption(bool, "callbacks", main_callbacks);
    const sdl3_main = b.option(bool, "main", "Enable SDL main") orelse false;
    options.addOption(bool, "main", sdl3_main);
    options.addOption(
        usize,
        "log_message_stack_size",
        b.option(
            usize,
            "log_message_stack_size",
            "Default log message stack size",
        ) orelse 1024,
    );
    options.addOption(
        usize,
        "renderer_debug_text_stack_size",
        b.option(
            usize,
            "renderer_debug_text_stack_size",
            "Default renderer debug text stack size",
        ) orelse 1024,
    );

    // SDL extension options.
    const extension_options = b.addOptions();
    const ext_image = b.option(bool, "ext_image", "Enable SDL_image extension") orelse false;
    extension_options.addOption(bool, "image", ext_image);
    const ext_net = b.option(bool, "ext_net", "Enable SDL_net extension") orelse false;
    extension_options.addOption(bool, "net", ext_net);
    const ext_ttf = b.option(bool, "ext_ttf", "Enable SDL_ttf extension") orelse false;
    extension_options.addOption(bool, "ttf", ext_ttf);

    const c_source_code = b.fmt(
        \\#include <SDL3/SDL.h>
        \\{s}
        \\#include <SDL3/SDL_main.h>
        \\#include <SDL3/SDL_vulkan.h>
        \\
        \\{s}
        \\{s}
        \\{s}
    , .{
        if (!sdl3_main) "#define SDL_MAIN_NOIMPL\n" else "",
        if (ext_image) "#include <SDL3_image/SDL_image.h>\n" else "",
        if (ext_net) "#include <SDL3_net/SDL_net.h>\n" else "",
        if (ext_ttf) "#include <SDL3_ttf/SDL_ttf.h>\n#include <SDL3_ttf/SDL_textengine.h>\n" else "",
    });

    const c_source_file_step = b.addWriteFiles();
    const c_source_path = c_source_file_step.add("c.c", c_source_code);

    const translate_c = b.addTranslateC(.{
        .root_source_file = c_source_path,
        .target = target,
        .optimize = optimize,
    });
    translate_c.addIncludePath(sdl_dep.path("include"));
    if (sdl_system_include_path) |val|
        translate_c.addSystemIncludePath(val);

    const c_module = translate_c.createModule();

    const sdl3 = b.addModule("sdl3", .{
        .root_source_file = cfg.root_source_file,
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c", .module = c_module },
        },
    });

    if (sdl_system_include_path) |val|
        sdl3.addSystemIncludePath(val);

    const example_options = ExampleOptions{
        .ext_image = ext_image,
        .ext_net = ext_net,
        .ext_ttf = ext_ttf,
    };

    sdl3.addOptions("extension_options", extension_options);
    sdl3.addOptions("options", options);
    sdl3.linkLibrary(sdl_dep_lib);

    if (ext_image) {
        image.setup(b, sdl3, translate_c, sdl_dep_lib, c_sdl_preferred_linkage, .{
            .optimize = optimize,
            .target = target,
        }, sdl_system_include_path);
    }
    if (ext_net) {
        net.setup(b, sdl3, translate_c, sdl_dep_lib, c_sdl_preferred_linkage, .{
            .optimize = optimize,
            .target = target,
        }, sdl_system_include_path);
    }
    if (ext_ttf) {
        ttf.setup(b, sdl3, translate_c, sdl_dep_lib, c_sdl_preferred_linkage, .{
            .optimize = optimize,
            .target = target,
        }, sdl_system_include_path);
    }

    _ = setupDocs(b, sdl3);
    _ = setupTest(b, cfg, extension_options, options, c_module);

    _ = try setupExamples(b, sdl3, cfg, example_options);
    _ = try runExample(b, sdl3, cfg, example_options);
}

pub fn setupDocs(b: *std.Build, sdl3: *std.Build.Module) *std.Build.Step {
    const sdl3_lib = b.addLibrary(.{
        .root_module = sdl3,
        .name = "sdl3",
    });
    const docs = b.addInstallDirectory(.{
        .source_dir = sdl3_lib.getEmittedDocs(),
        .install_dir = .{ .prefix = {} },
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate library documentation");
    docs_step.dependOn(&docs.step);
    return docs_step;
}

pub fn setupExample(b: *std.Build, sdl3: *std.Build.Module, cfg: Config, name: []const u8) !*std.Build.Step.Compile {
    const exe_module = b.createModule(.{
        .root_source_file = b.path(try std.fmt.allocPrint(b.allocator, "examples/{s}.zig", .{name})),
        .target = cfg.target,
        .optimize = cfg.optimize,
        .imports = &.{
            .{ .name = "sdl3", .module = sdl3 },
        },
    });
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = exe_module,
        .version = cfg.version,
    });
    b.installArtifact(exe);
    return exe;
}

pub fn runExample(b: *std.Build, sdl3: *std.Build.Module, cfg: Config, options: ExampleOptions) !void {
    const run_example: ?[]const u8 = b.option([]const u8, "example", "The example name for running an example") orelse null;
    const run = b.step("run", "Run an example with -Dexample=<example_name> option");
    if (run_example) |example| {
        var can_run = true;
        // TODO unhardcode if we will need more extension-specific examples
        if (std.mem.eql(u8, example, "net")) {
            can_run = options.ext_net;
        }
        if (std.mem.eql(u8, example, "ttf")) {
            can_run = options.ext_ttf;
        }

        if (can_run) {
            const run_art = b.addRunArtifact(try setupExample(b, sdl3, cfg, example));
            run_art.step.dependOn(b.getInstallStep());
            run.dependOn(&run_art.step);
        }
    }
}

pub fn setupExamples(b: *std.Build, sdl3: *std.Build.Module, cfg: Config, options: ExampleOptions) !*std.Build.Step {
    const exp = b.step("examples", "Build all examples");
    const examples_dir = b.path("examples");
    var dir = (try std.fs.openDirAbsolute(examples_dir.getPath(b), .{ .iterate = true }));
    defer dir.close();
    var dir_iterator = try dir.walk(b.allocator);
    defer dir_iterator.deinit();
    while (try dir_iterator.next()) |file| {
        if (file.kind == .file and std.mem.endsWith(u8, file.basename, ".zig")) {
            const name = file.basename[0 .. file.basename.len - 4];
            var build_example = true;
            // TODO unhardcode if we will need more extension-specific examples
            if (std.mem.eql(u8, name, "net")) {
                build_example = options.ext_net;
            }
            if (std.mem.eql(u8, name, "ttf")) {
                build_example = options.ext_ttf;
            }

            if (build_example) {
                _ = try setupExample(b, sdl3, cfg, name);
            }
        }
    }
    exp.dependOn(b.getInstallStep());
    return exp;
}

pub fn setupTest(b: *std.Build, cfg: Config, extension_options: *std.Build.Step.Options, options: *std.Build.Step.Options, c_module: *std.Build.Module) *std.Build.Step.Compile {
    const test_module = b.createModule(.{
        .root_source_file = cfg.root_source_file,
        .target = cfg.target,
        .optimize = cfg.optimize,
        .imports = &.{
            .{ .name = "c", .module = c_module },
        },
    });
    const tst = b.addTest(.{
        .name = cfg.name,
        .root_module = test_module,
    });
    tst.root_module.addOptions("extension_options", extension_options);
    tst.root_module.addOptions("options", options);
    const sdl_dep = b.dependency("sdl", .{
        .target = cfg.target,
        .optimize = cfg.optimize,
    });
    const sdl_dep_lib = sdl_dep.artifact("SDL3");
    tst.root_module.linkLibrary(sdl_dep_lib);
    const tst_run = b.addRunArtifact(tst);
    const tst_step = b.step("test", "Run all tests");
    tst_step.dependOn(&tst_run.step);
    return tst;
}

const Config = struct {
    name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_source_file: std.Build.LazyPath,
    version: std.SemanticVersion,
};
