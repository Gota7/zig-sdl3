const std = @import("std");

// https://github.com/allyourcodebase/SDL_ttf/blob/main/build.zig
pub fn setup(b: *std.Build, sdl3: *std.Build.Module, sdl_dep_lib: *std.Build.Step.Compile, linkage: std.builtin.LinkMode, cfg: std.Build.TestOptions) void {
    const target = cfg.target orelse b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = .ReleaseFast; // https://github.com/libsdl-org/SDL_ttf/issues/566 (ReleaseFast prevents UBSAN from running)

    const harfbuzz_enabled = b.option(bool, "enable-harfbuzz", "Use HarfBuzz to improve text shaping") orelse true;
    const upstream = b.lazyDependency("sdl_ttf", .{}) orelse return;

    const lib = b.addLibrary(.{
        .name = "SDL3_ttf",
        .version = .{ .major = 3, .minor = 2, .patch = 2 },
        .linkage = linkage,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    lib.addIncludePath(upstream.path("include"));
    lib.addIncludePath(upstream.path("src"));
    lib.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = srcs,
    });

    if (harfbuzz_enabled) {
        const harfbuzz_dep = b.dependency("harfbuzz", .{
            .target = target,
            .optimize = optimize,
        });
        lib.linkLibrary(harfbuzz_dep.artifact("harfbuzz"));
        lib.root_module.addCMacro("TTF_USE_HARFBUZZ", "1");
    }

    const freetype_dep = b.dependency("freetype", .{
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibrary(freetype_dep.artifact("freetype"));

    lib.linkLibrary(sdl_dep_lib);
    lib.installHeadersDirectory(upstream.path("include"), "", .{});

    b.installArtifact(lib);

    sdl3.linkLibrary(lib);
    sdl3.addIncludePath(upstream.path("include"));
}

const srcs: []const []const u8 = &.{
    "SDL_gpu_textengine.c",
    "SDL_hashtable.c",
    "SDL_hashtable_ttf.c",
    "SDL_renderer_textengine.c",
    "SDL_surface_textengine.c",
    "SDL_ttf.c",
};
