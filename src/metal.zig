const C = @import("c.zig").C;
const init = @import("init.zig");
const std = @import("std");
const video = @import("video.zig");

/// A handle to a `CAMetalLayer`-backed `NSView` (macOS) or `UIView` (iOS/tvOS).
pub const View = packed struct {
    value: *anyopaque,

    /// Destroy an existing `View` object.
    ///
    /// ## Function Parameters
    /// * `self`: The view object.
    ///
    /// ## Remarks
    /// This should be called before `video.Window.deinit()`, if `metal.View.init()` was called after `video.Window.init()`.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn deinit(
        self: View,
    ) void {
        C.SDL_Metal_DestroyView(self.value);
    }

    /// Get a pointer to the backing `CAMetalLayer` for the given view.
    ///
    /// ## Function Parameters
    /// * `self`: The view object.
    ///
    /// ## Return Value
    /// Returns a pointer.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getLayer(
        self: View,
    ) ?*anyopaque {
        return C.SDL_Metal_GetLayer(self.value);
    }

    /// Create a `CAMetalLayer`-backed `NSView`/`UIView` and attach it to the specified window.
    ///
    /// ## Function Parameters
    /// * `window`: The window.
    ///
    /// ## Return Value
    /// Returns handle `NSView` or `UIView`.
    ///
    /// ## Remarks
    /// On macOS, this does not associate a `MTLDevice` with the `CAMetalLayer` on its own. It is up to user code to do that.
    ///
    /// The returned handle can be casted directly to a `NSView` or `UIView`.
    /// To access the backing `CAMetalLayer`, call `metal.getLayer()`.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn init(
        window: video.Window,
    ) ?View {
        return .{ .value = C.SDL_Metal_CreateView(window.value) orelse return null };
    }
};

// Metal glue layer tests.
test "Metal" {
    defer init.shutdown();
    const flags = init.Flags{ .video = true };
    try init.init(flags);
    defer init.quit(flags);

    const window = try video.Window.init("testing", 10, 10, .{});
    defer window.deinit();

    const view_raw = View.init(window);
    if (view_raw) |view| {
        defer view.deinit();
        _ = view.getLayer();
    }
}
