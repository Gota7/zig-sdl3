const std = @import("std");

pub fn setup(b: *std.Build, sdl3: *std.Build.Module, sdl_dep_lib: *std.Build.Step.Compile, linkage: std.builtin.LinkMode, cfg: std.Build.TestOptions) void {
    const target = cfg.target orelse b.standardTargetOptions(.{});
    const optimize = cfg.optimize;

    const upstream = b.lazyDependency("sdl_net", .{}) orelse return;
    const native_os = target.result.os.tag;

    const lib_name = "SDL3_net";
    const version = std.SemanticVersion.parse("3.0.0") catch unreachable;
    // Options.
    const shared = b.option(bool, "shared", "Build SDL_net as a shared library") orelse false;
    // Library.
    const lib = b.addLibrary(.{
        .name = lib_name,
        .version = version,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = linkage,
    });

    var lib_c_flags: std.ArrayList([]const u8) = .init(b.allocator);
    defer lib_c_flags.deinit();
    lib_c_flags.appendSlice(&.{"-std=c99"}) catch @panic("OOM");

    lib.root_module.addCSourceFile(.{
        .file = upstream.path("src/SDL_net.c"),
        .flags = lib_c_flags.items,
    });
    // Headers.
    lib.root_module.addIncludePath(upstream.path("include"));
    // Defines.
    lib.root_module.addCMacro("BUILD_SDL", "1");
    lib.root_module.addCMacro("SDL_BUILD_MAJOR_VERSION", b.fmt("{d}", .{version.major}));
    lib.root_module.addCMacro("SDL_BUILD_MINOR_VERSION", b.fmt("{d}", .{version.minor}));
    lib.root_module.addCMacro("SDL_BUILD_MICRO_VERSION", b.fmt("{d}", .{version.patch}));
    if (shared and native_os == .windows) {
        lib.root_module.addCMacro("DLL_EXPORT", "");
    }
    if (native_os != .windows and native_os != .haiku) {
        lib.root_module.addCMacro("_DEFAULT_SOURCE", "");
    }
    lib.root_module.linkLibrary(sdl_dep_lib);
    // Linking.
    if (native_os == .windows) {
        lib.root_module.linkSystemLibrary("iphlpapi", .{});
        lib.root_module.linkSystemLibrary("ws2_32", .{});
        if (shared) {
            lib.root_module.addWin32ResourceFile(.{ .file = upstream.path("src/version.rc") });
        }
    } else if (native_os == .haiku) {
        lib.root_module.linkSystemLibrary("network", .{});
    }
    // Linker version.
    if (target.result.ofmt == .elf or target.result.ofmt == .macho) {
        lib.setVersionScript(upstream.path("src/SDL_net.sym"));
    }
    if (shared) {
        lib.linker_allow_shlib_undefined = false;
    }

    b.installArtifact(lib);
    // Installation.
    const install_header = b.addInstallHeaderFile(upstream.path("include/SDL3_net/SDL_net.h"), "SDL3_net/SDL_net.h");
    b.getInstallStep().dependOn(&install_header.step);
    const install_license = b.addInstallFile(upstream.path("LICENSE.txt"), "share/licenses/SDL3_net/LICENSE.txt");
    b.getInstallStep().dependOn(&install_license.step);

    sdl3.linkLibrary(lib);
    sdl3.addIncludePath(upstream.path("include"));
}
