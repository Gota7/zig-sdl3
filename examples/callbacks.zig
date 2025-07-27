const sdl3 = @import("sdl3");
const std = @import("std");

const allocator = std.heap.smp_allocator;

const FPS = 60;
const SCREEN_WIDTH = 640;
const SCREEN_HEIGHT = 480;

/// Application state to keep track of.
const AppState = struct {
    fps_capper: sdl3.extras.FramerateCapper(f32),
    window: sdl3.video.Window,
};

/// Runs once on application startup.
fn init(
    app_state: *?*AppState,
    args: [][*:0]u8,
) !sdl3.AppResult {
    // Create window.
    // We use `errdefer` as we will only free items from the app with a created app state.
    const window = try sdl3.video.Window.init(std.mem.span(args[0]), SCREEN_WIDTH, SCREEN_HEIGHT, .{});
    errdefer window.deinit();

    // Finally create the application state.
    const state = try allocator.create(AppState);
    state.* = .{
        .fps_capper = .{ .mode = .{ .limited = FPS } },
        .window = window,
    };
    app_state.* = state;
    return .run;
}

/// Iterate function that is called once every frame.
fn iterate(
    app_state: ?*AppState,
) !sdl3.AppResult {
    const state = app_state orelse return .failure;

    // Update loop here.
    const surface = try state.window.getSurface();
    try surface.fillRect(null, surface.mapRgb(128, 30, 255));
    try state.window.updateSurface();

    // Delay to maintain FPS, returned delta time not needed.
    _ = state.fps_capper.delay();
    return .run;
}

/// Event loop function for when an event is recieved.
fn event(
    app_state: ?*AppState,
    curr_event: sdl3.events.Event,
) !sdl3.AppResult {
    _ = app_state;

    return switch (curr_event) {
        .quit => .success,
        .terminating => .success,
        else => .run,
    };
}

/// Called when quitting.
fn quit(
    app_state: ?*AppState,
    result: sdl3.AppResult,
) void {
    _ = result;

    // We only want to de-initialize if initialization was successful.
    if (app_state) |state| {
        state.window.deinit();
        allocator.destroy(state);
    }
}

pub fn main() u8 {

    // Example on how to use callbacks for a project that does not use them as a build option.
    // For an example on how to create a project using the callbacks without this, see the template.
    sdl3.main_funcs.setMainReady();
    var args = [_:null]?[*:0]u8{
        @constCast("Hello SDL3"),
    };
    return sdl3.main_funcs.enterAppMainCallbacks(&args, AppState, init, iterate, event, quit);
}
