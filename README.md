zig-sdl3
========

A lightweight wrapper to zig-ify SDL3.

> [!WARNING]
> This is not production ready and currently in development!
>
> I'm hoping to be done soon, great progress has been made so far!
>
> See the [checklist](checklist.md) for more details on progress.
>
> However, most of the library is stable and usable!

# Documentation
[https://gota7.github.io/zig-sdl3/](https://gota7.github.io/zig-sdl3/)

# About

This library aims to unite the power of SDL3 with general zigisms to feel right at home alongside the zig standard library.
SDL3 is compatible with many different platforms, making it the perfect library to pair with zig.
Some advantages of SDL3 include windowing, audio, gamepad, keyboard, mouse, rendering, and GPU abstractions across all supported platforms.

# Building and using

To use zig-sdl3, you need to add it as a dependency to your project. The branch you should use depends on your Zig version.
Choose the command that matches your Zig version and run it in your project's root directory
* For 0.14.0:
```sh
zig fetch --save git+https://github.com/Gota7/zig-sdl3#master
```
* For Zig master (nightly):
```sh
zig fetch --save git+https://github.com/Gota7/zig-sdl3#zig-master
```

Then add zig-sdl3 as a dependency and import its modules and artifact in your `build.zig`:

```zig
const sdl3 = b.dependency("sdl3", .{
    .target = target,
    .optimize = optimize,

    // Lib options.
    /// .callbacks = false,
    /// .ext_image = false,

    // Options passed directly to https://github.com/castholm/SDL (SDL3 C Bindings):
    // .c_sdl_preferred_linkage = .static,
    // .c_sdl_strip = false,
    // .c_sdl_sanitize_c = .off,
    // .c_sdl_lto = .none,
    // .c_sdl_emscripten_pthreads = false,
    // .c_sdl_install_build_config_h = false,

    // Options if `ext_image` is enabled:
    // .image_enable_bmp = true,
    // .image_enable_gif = true,
    // .image_enable_jpg = true,
    // .image_enable_lbm = true,
    // .image_enable_pcx = true,
    // .image_enable_png = true,
    // .image_enable_pnm = true,
    // .image_enable_qoi = true,
    // .image_enable_svg = true,
    // .image_enable_tga = true,
    // .image_enable_xcf = true,
    // .image_enable_xpm = true,
    // .image_enable_xv = true,
});
```
Now add the modules and artifact to your target as you would normally:

```zig
lib.root_module.addImport("sdl3", sdl3.module("sdl3"));
```

# Example

```zig
const sdl3 = @import("sdl3");
const std = @import("std");

const SCREEN_WIDTH = 640;
const SCREEN_HEIGHT = 480;

pub fn main() !void {
    defer sdl3.shutdown();

    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    const window = try sdl3.video.Window.init("Hello SDL3", SCREEN_WIDTH, SCREEN_HEIGHT, .{});
    defer window.deinit();

    const surface = try window.getSurface();
    try surface.fillRect(null, surface.mapRgb(128, 30, 255));
    try window.updateSurface();

    while (true) {
        switch (try sdl3.events.waitAndPop()) {
            .quit => break,
            .terminating => break,
            else => {},
        }
    }
}
```

# Structure

## Source

The `src` folder was originally generated via a binding generator, but manually perfecting and testing the subsystems was found to be more productive.
Each source file must also call each function at least once in testing if possible to ensure compilation is successful.

## Examples

The `examples` directory has some example programs utilizing SDL3.
All examples may be built with `zig build examples`, or a single example can be ran with `zig build run -Dexample=<example name>`.

## Template

The `template` directory contains a sample hello world to get started using SDL3.
Simply copy this folder to use as your project, and have fun!

## Tests

Tests for the library can be ran by running `zig build test`.

# Features

* SDL subsystems are divided into convenient namespaces.
* Functions that can fail have the return wrapped with an error type and can even call a custom error callback.
* C namespace exporting raw SDL functions in case it is ever needed.
* Standard `init` and `deinit` functions for creating and destroying resources.
* Skirts around C compat weirdness when possible (C pointers, anyopaque, C types).
* Naming and conventions are more consistent with zig.
* Functions return values rather than write to pointers.
* Types that are intended to be nullable are now clearly annotated as such with optionals.
* Easy conversion to/from SDL types from the wrapped types.
* The `self.function()` notation is used where applicable.

# FAQ

## How Do I Get Started?

The easiest way is to copy the template, and comment out the `path` in the zon file and uncomment the `url`.
Fix the hash as needed.
The template uses the callback method, an extension lib, and overall shows how the wrapper can be used to create an application.

## When Is 1.0.0 Being Released?

When it's ready, you can track progress by looking at the milestones.
My free time is limited, but trust me my top priority is getting this out soon!

## GPU Examples?

I will try and get these done before 1.0.0.
The original goal was to use zig shaders, but unfortunately the current zig release does not support the ability to run every example.
The examples using zig shaders have been moved to https://github.com/Gota7/zig-sdl3-gpu-examples.
Depending on when zig 15.0.0 releases, I may or may not implement all the GPU examples in HLSL.

## HLSL Examples?

There will be at least one that exists before 1.0.0 is released.

## Symlink Error

If you get something like this on Windows:
```
C:\...\zig\p\SDL_image-3.2.4--aJoHa0VAAC_C_du38OrOmZ4m23B5bCjXONc13NEpTYf\build.zig.zon:12:20: error: unable to unpack packfile
            .url = "git+https://github.com/libsdl-org/SDL_image#release-3.2.4",
                   ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
note: unable to create symlink from 'Xcode\macOS\SDL3.framework\Headers' to 'Versions/Current/Headers': AccessDenied
note: unable to create symlink from 'Xcode\macOS\SDL3.framework\Resources' to 'Versions/Current/Resources': AccessDenied
note: unable to create symlink from 'Xcode\macOS\SDL3.framework\SDL3.tbd' to 'Versions/Current/SDL3.tbd': AccessDenied
note: unable to create symlink from 'Xcode\macOS\SDL3.framework\Versions\Current' to 'A': AccessDenied
```

See this:
https://github.com/Gota7/zig-sdl3/issues/21
