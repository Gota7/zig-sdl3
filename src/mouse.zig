const C = @import("c.zig").C;
const errors = @import("errors.zig");
const init = @import("init.zig");
const rect = @import("rect.zig");
const std = @import("std");
const stdinc = @import("stdinc.zig");
const surface = @import("surface.zig");
const video = @import("video.zig");

/// A callback used to transform mouse motion delta from raw values.
///
/// ## Function Parameters
/// * `user_data`: User data passed to `mouse.setRelativeTransform()`.
/// * `timestamp`: The associated time at which this mouse motion event was received.
/// * `window`: The associated window to which this mouse motion event was addressed.
/// * `id`: The associated mouse from which this mouse motion event was emitted.
/// * `x`: Pointer to a variable that will be treated as the resulting x-axis motion.
/// * `y`: Pointer to a variable that will be treated as the resulting y-axis motion.
///
/// ## Remarks
/// This is called during SDL's handling of platform mouse events to scale the values of the resulting motion delta.
///
/// ## Thread Safety
/// This callback is called by SDL's internal mouse input processing procedure,
/// which may be a thread separate from the main event loop that is run at realtime priority.
/// Stalling this thread with too much work in the callback can therefore potentially freeze the entire system.
/// Care should be taken with proper synchronization practices when adding other side effects beyond mutation of
/// the `x` and `y` values.
///
/// ## Version
/// This datatype is available since SDL 3.2.6.
pub const MotionTransformCallback = *const fn (user_data: ?*anyopaque, timestamp: u64, window: ?*C.SDL_Window, id: C.SDL_MouseID, x: ?*f32, y: ?*f32) callconv(.C) void;

/// Enum identifying mouse buttons
pub const Button = enum(c_int) {
    left = C.SDL_BUTTON_LEFT,
    middle = C.SDL_BUTTON_MIDDLE,
    right = C.SDL_BUTTON_RIGHT,
    x1 = C.SDL_BUTTON_X1,
    x2 = C.SDL_BUTTON_X2,
    _,
};

/// A bitmask of pressed mouse buttons, as reported by `mouse.getState()`, etc.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const ButtonFlags = struct {
    left: bool,
    middle: bool,
    right: bool,
    side1: bool,
    side2: bool,

    /// Get button flags from an SDL value.
    pub fn fromSdl(value: C.SDL_MouseButtonFlags) ButtonFlags {
        return .{
            .left = value & C.SDL_BUTTON_LEFT > 0,
            .middle = value & C.SDL_BUTTON_MIDDLE > 0,
            .right = value & C.SDL_BUTTON_RIGHT > 0,
            .side1 = value & C.SDL_BUTTON_X1 > 0,
            .side2 = value & C.SDL_BUTTON_X2 > 0,
        };
    }

    /// Get this as an SDL value.
    pub fn toSdl(self: ButtonFlags) C.SDL_MouseButtonFlags {
        var ret: C.SDL_MouseButtonFlags = 0;
        if (self.left)
            ret |= C.SDL_BUTTON_LEFT;
        if (self.middle)
            ret |= C.SDL_BUTTON_MIDDLE;
        if (self.right)
            ret |= C.SDL_BUTTON_RIGHT;
        if (self.side1)
            ret |= C.SDL_BUTTON_X1;
        if (self.side2)
            ret |= C.SDL_BUTTON_X2;
        return ret;
    }
};

/// This is a unique ID for a mouse for the time it is connected to the system,
/// and is never reused for the lifetime of the application.
///
/// ## Remarks
/// If the mouse is disconnected and reconnected, it will get a new ID.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const ID = packed struct {
    value: C.SDL_MouseID,

    // Size tests.
    comptime {
        std.debug.assert(@sizeOf(C.SDL_MouseID) == @sizeOf(ID));
    }

    /// The `mouse.ID` for mouse events simulated with pen input.
    ///
    /// ## Version
    /// This constant is available since SDL 3.2.0.
    pub const pen = ID{ .value = C.SDL_PEN_MOUSEID };

    /// The `mouse.ID` for mouse events simulated with touch input.
    ///
    /// ## Version
    /// This constant is available since SDL 3.2.0.
    pub const touch = ID{ .value = C.SDL_TOUCH_MOUSEID };

    /// Get from an SDL value.
    pub fn fromSdl(value: C.SDL_MouseID) ?ID {
        if (value == 0)
            return null;
        return .{ .value = value };
    }

    /// Get an SDL value.
    pub fn toSdl(self: ?ID) C.SDL_MouseID {
        if (self) |val| {
            return val.value;
        }
        return 0;
    }

    /// Get the name of a mouse.
    ///
    /// ## Function Parameters
    /// * `self`: The mouse instance ID.
    ///
    /// ## Return Value
    /// Returns the name of the mouse.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getName(
        self: ID,
    ) !?[:0]const u8 {
        const ret = try errors.wrapCallCString(C.SDL_GetMouseNameForID(self.value));
        if (std.mem.eql(u8, ret, ""))
            return null;
        return ret;
    }
};

/// Cursor types for `mouse.Cursor.initSystem()`.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const SystemCursor = enum(c_uint) {
    /// Default cursor. Usually an arrow.
    default = C.SDL_SYSTEM_CURSOR_DEFAULT,
    /// Text selection. Usually an I-beam.
    text = C.SDL_SYSTEM_CURSOR_TEXT,
    /// Wait. Usually an hourglass or watch or spinning ball.
    wait = C.SDL_SYSTEM_CURSOR_WAIT,
    /// Crosshair.
    crosshair = C.SDL_SYSTEM_CURSOR_CROSSHAIR,
    /// Program is busy but still interactive. Usually it's `mouse.SystemCursor.wait` with an arrow.
    progress = C.SDL_SYSTEM_CURSOR_PROGRESS,
    /// Double arrow pointing northwest and southeast.
    northwest_southeast_resize = C.SDL_SYSTEM_CURSOR_NWSE_RESIZE,
    /// Double arrow pointing northeast and southwest.
    northeast_southwest_resize = C.SDL_SYSTEM_CURSOR_NESW_RESIZE,
    /// Double arrow pointing west and east.
    east_west_resize = C.SDL_SYSTEM_CURSOR_EW_RESIZE,
    /// Double arrow pointing north and south.
    north_south_resize = C.SDL_SYSTEM_CURSOR_NS_RESIZE,
    /// Four pointed arrow pointing north, south, east, and west.
    move = C.SDL_SYSTEM_CURSOR_MOVE,
    /// Not permitted. Usually a slashed circle or crossbones.
    not_allowed = C.SDL_SYSTEM_CURSOR_NOT_ALLOWED,
    /// Pointer that indicates a link. Usually a pointing hand.
    pointer = C.SDL_SYSTEM_CURSOR_POINTER,
    /// Window resize top-left. This may be a single arrow or a double arrow like `mouse.SystemCursor.resize`.
    north_west_resize = C.SDL_SYSTEM_CURSOR_NW_RESIZE,
    /// Window resize top. May be `mouse.SystemCursor.north_south_resize`.
    north_resize = C.SDL_SYSTEM_CURSOR_N_RESIZE,
    /// Window resize top-right. May be `mouse.SystemCursor.northeast_southwest_resize`.
    north_east_resize = C.SDL_SYSTEM_CURSOR_NE_RESIZE,
    /// Window resize right. May be `mouse.SystemCursor.east_west_resize`.
    east_resize = C.SDL_SYSTEM_CURSOR_E_RESIZE,
    /// Window resize bottom-right. May be `mouse.SystemCursor.northwest_southeast_resize`.
    southeast_resize = C.SDL_SYSTEM_CURSOR_SE_RESIZE,
    /// Window resize bottom. May be `mouse.SystemCursor.north_south_resize`.
    south_resize = C.SDL_SYSTEM_CURSOR_S_RESIZE,
    /// Window resize bottom-left. May be `mouse.SystemCursor.northeast_southwest_resize`.
    southwest_resize = C.SDL_SYSTEM_CURSOR_SW_RESIZE,
    /// Window resize left. May be `mouse.SystemCursor.east_west_resize`.
    west_resize = C.SDL_SYSTEM_CURSOR_W_RESIZE,
};

/// Scroll direction types for the `events.Type.scroll` event.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const WheelDirection = enum(c_uint) {
    /// The scroll direction is normal.
    normal,
    /// The scroll direction is flipped/natural.
    flipped,
};

/// The structure used to identify an SDL cursor.
///
/// ## Remarks
/// This is opaque data.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const Cursor = packed struct {
    value: *C.SDL_Cursor,

    /// Free a previously-created cursor.
    ///
    /// ## Function Parameters
    /// * `self`: The cursor to free.
    ///
    /// ## Remarks
    /// Remarks
    /// Use this function to free cursor resources created with `cursor.Cursor.init()`, `cursor.Cursor.initColor()`,
    /// or `cursor.Cursor.initSystem()`.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn deinit(
        self: Cursor,
    ) void {
        C.SDL_DestroyCursor(self.value);
    }

    /// Create a cursor using the specified bitmap data and mask (in MSB format).
    ///
    /// ## Function Parameters
    /// * `data`: The color value for each pixel of the cursor.
    /// * `mask`: The mask value for each pixel of the cursor.
    /// * `width`: The width of the cursor.
    /// * `height`: The height of the cursor.
    /// * `hot_x`: The x-axis offset from the left of the cursor image to the mouse x position, in the range of `0` to `width - 1`.
    /// * `hot_y`: The y-axis offset from the top of the cursor image to the mouse y position, in the range of `0` to `height - 1`.
    ///
    /// ## Return Value
    /// Returns a new cursor.
    ///
    /// ## Remarks
    /// `mask` has to be in MSB (Most Significant Bit) format.
    ///
    /// The cursor width (`width`) must be a multiple of 8 bits.
    ///
    /// The cursor is created in black and white according to the following:
    /// * data=0, mask=1: White.
    /// * data=1, mask=1: Black.
    /// * data=0, mask=0: Transparent.
    /// * data=1, mask=0: Inverted color if possible, black if not.
    ///
    /// Cursors created with this function must be freed with `mouse.Cursor.deinit()`.
    ///
    /// If you want to have a color cursor, or create your cursor from a `surface.Surface`, you should use `mouse.Cursor.initColor()`.
    /// Alternately, you can hide the cursor and draw your own as part of your game's rendering, but it will be bound to the framerate.
    ///
    /// Also, `mouse.Cursor.initSystem()` is available, which provides several readily-available system cursors to pick from.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// Version
    /// This function is available since SDL 3.2.0.
    ///
    /// ## Code Examples
    /// TODO!!!
    pub fn init(
        data: [*]const u8,
        mask: [*]const u8,
        width: usize,
        height: usize,
        hot_x: usize,
        hot_y: usize,
    ) !Cursor {
        return .{ .value = try errors.wrapNull(*C.SDL_Cursor, C.SDL_CreateCursor(
            data,
            mask,
            @intCast(width),
            @intCast(height),
            @intCast(hot_x),
            @intCast(hot_y),
        )) };
    }

    /// Create a color cursor.
    ///
    /// ## Function Parameters
    /// * `cursor_surface`: A `surface.Surface` structure representing the cursor image.
    /// * `hot_x`: The x position of the cursor hot spot.
    /// * `hot_y`: The y position of the cursor hot spot.
    ///
    /// ## Return Value
    /// Returns a new cursor.
    ///
    /// ## Remarks
    /// If this function is passed a surface with alternate representations,
    /// the surface will be interpreted as the content to be used for 100% display scale,
    /// and the alternate representations will be used for high DPI situations.
    /// For example, if the original surface is 32x32, then on a 2x macOS display or 200% display scale on Windows,
    /// a 64x64 version of the image will be used, if available.
    /// If a matching version of the image isn't available,
    /// the closest larger size image will be downscaled to the appropriate size and be used instead, if available.
    /// Otherwise, the closest smaller image will be upscaled and be used instead.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    ///
    /// ## Code Examples
    /// TODO!!!
    pub fn initColor(
        cursor_surface: surface.Surface,
        hot_x: usize,
        hot_y: usize,
    ) !Cursor {
        return .{ .value = try errors.wrapNull(*C.SDL_Cursor, C.SDL_CreateColorCursor(
            cursor_surface.value,
            @intCast(hot_x),
            @intCast(hot_y),
        )) };
    }

    /// Create a system cursor.
    ///
    /// ## Function Parameters
    /// * `id`: A system cursor enumeration value.
    ///
    /// ## Return Value
    /// Returns a new cursor.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    ///
    /// ## Code Examples
    /// ```zig
    /// const my_cursor = try mouse.Cursor.initSystem(.pointer);
    /// mouse.set(my_cursor);
    /// ```
    pub fn initSystem(
        id: SystemCursor,
    ) !Cursor {
        return .{ .value = try errors.wrapNull(
            *C.SDL_Cursor,
            C.SDL_CreateSystemCursor(@intFromEnum(id)),
        ) };
    }
};

/// Capture the mouse and to track input outside an SDL window.
///
/// ## Function Parameters
/// * `enable`: True to enable capturing, false to disable.
///
/// ## Remarks
/// Capturing enables your app to obtain mouse events globally, instead of just within your window.
/// Not all video targets support this function.
/// When capturing is enabled, the current window will get all mouse events, but unlike relative mode,
/// no change is made to the cursor and it is not restrained to your window.
///
/// This function may also deny mouse input to other windows, both those in your application and others on the system,
/// so you should use this function sparingly, and in small bursts.
/// For example, you might want to track the mouse while the user is dragging something,
/// until the user releases a mouse button.
/// It is not recommended that you capture the mouse for long periods of time, such as the entire time your app is running.
/// For that, you should probably use `mouse.setWindowRelativeMode()` or `mouse.setWindowGrab()`, depending on your goals.
///
/// While captured, mouse events still report coordinates relative to the current (foreground) window,
/// but those coordinates may be outside the bounds of the window (including negative values).
/// Capturing is only allowed for the foreground window.
/// If the window loses focus while capturing, the capture will be disabled automatically.
///
/// While capturing is enabled, the current window will have the `video.WindowFlags.mouse_capture` flag set.
///
/// Please note that SDL will attempt to "auto capture" the mouse while the user is pressing a button;
/// this is to try and make mouse behavior more consistent between platforms,
/// and deal with the common case of a user dragging the mouse outside of the window.
/// This means that if you are calling `mouse.capture()` only to deal with this situation,
/// you do not have to (although it is safe to do so).
/// If this causes problems for your app, you can disable auto capture by setting the `hints.Type.mouse_auto_capture` hint to zero.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn capture(
    enable: bool,
) !void {
    return errors.wrapCallBool(C.SDL_CaptureMouse(enable));
}

/// Get the active cursor.
///
/// ## Return Value
/// Returns the active cursor or `null` if there is no mouse.
///
/// ## Remarks
/// This function returns a pointer to the current cursor which is owned by the library.
/// It is not necessary to free the cursor with `cursor.Cursor.deinit()`.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn get() ?Cursor {
    const ret = C.SDL_GetCursor();
    if (ret) |val| {
        return .{ .value = val };
    }
    return null;
}

/// Get the default cursor.
///
/// ## Return Value
/// Returns the default cursor.
///
/// ## Remarks
/// You do not have to call `cursor.Cursor.deinit()` on the returned value, but it is safe to do so.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getDefault() !Cursor {
    return .{
        .value = try errors.wrapNull(*C.SDL_Cursor, C.SDL_GetDefaultCursor()),
    };
}

/// Get the window which currently has mouse focus.
///
/// ## Return Value
/// Returns the window with the mouse focus.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getFocus() ?video.Window {
    if (C.SDL_GetMouseFocus()) |val| {
        return .{
            .value = val,
        };
    }
    return null;
}

/// Query the platform for the asynchronous mouse button state and the desktop-relative platform-cursor position.
///
/// ## Return Value
/// Returns the mouse button state, as well as the x and y position from the desktop's top-left corner.
///
/// ## Remarks
/// This function immediately queries the platform for the most recent asynchronous state,
/// more costly than retrieving SDL's cached state in `mouse.getState()`.
///
/// In Relative Mode, the platform-cursor's position usually contradicts the SDL-cursor's position
/// as manually calculated from `mouse.getState()` and `video.Window.getPosition()`.
///
/// This function can be useful if you need to track the mouse outside of a specific window and `mouse.capture()` doesn't fit your needs.
/// For example, it could be useful if you need to track the mouse while dragging a window,
/// where coordinates relative to a window might not be in sync at all times.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getGlobalState() struct { flags: ButtonFlags, x: f32, y: f32 } {
    var x: f32 = undefined;
    var y: f32 = undefined;
    const flags = C.SDL_GetGlobalMouseState(&x, &y);
    return .{
        .flags = ButtonFlags.fromSdl(flags),
        .x = x,
        .y = y,
    };
}

/// Get a list of currently connected mice.
///
/// ## Return Value
/// Returns a list of mouse instance IDs, these should be freed with `stdinc.free()` when no longer needed.
///
/// ## Remarks
/// Note that this will include any device or virtual driver that includes mouse functionality,
/// including some game controllers, KVM switches, etc.
/// You should wait for input from a device before you consider it actively in use.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getMice() ![]ID {
    var len: c_int = undefined;
    const val = C.SDL_GetMice(&len);
    const ret: [*]ID = @ptrCast(try errors.wrapCallCPtr(u32, val));
    return ret[0..@intCast(len)];
}

/// Query SDL's cache for the synchronous mouse button state and accumulated mouse delta since last call.
///
/// ## Return Value
/// Returns the mouse button state, as well as the x and y delta accumulated from the last call.
///
/// ## Remarks
/// This function returns the cached synchronous state as SDL understands it from the last pump of the event queue.
///
/// To query the platform for immediate asynchronous state, use `mouse.getGlobalState()`.
///
/// In Relative Mode, the platform-cursor's position usually contradicts the SDL-cursor's position
/// as manually calculated from `mouse.getState()` and `video.Window.getPosition()`.
///
/// This function is useful for reducing overhead by processing relative mouse inputs in one go per-frame
/// instead of individually per-event, at the expense of losing the order between events within the frame
/// (e.g. quickly pressing and releasing a button within the same frame).
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getRelativeState() struct { flags: ButtonFlags, x: f32, y: f32 } {
    var x: f32 = undefined;
    var y: f32 = undefined;
    const flags = C.SDL_GetRelativeMouseState(&x, &y);
    return .{
        .flags = ButtonFlags.fromSdl(flags),
        .x = x,
        .y = y,
    };
}

/// Query SDL's cache for the synchronous mouse button state and the window-relative SDL-cursor position.
///
/// ## Return Value
/// Returns the mouse button state, as well as the x and y position from the desktop's top-left corner.
///
/// ## Remarks
/// This function returns the cached synchronous state as SDL understands it from the last pump of the event queue.
///
/// To query the platform for immediate asynchronous state, use `mouse.getGlobalState()`.
///
/// In Relative Mode, the platform-cursor's position usually contradicts the SDL-cursor's position
/// as manually calculated from `mouse.getState()` and `video.Window.getPosition()`.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getState() struct { flags: ButtonFlags, x: f32, y: f32 } {
    var x: f32 = undefined;
    var y: f32 = undefined;
    const flags = C.SDL_GetMouseState(&x, &y);
    return .{
        .flags = ButtonFlags.fromSdl(flags),
        .x = x,
        .y = y,
    };
}

/// Get a window's mouse grab mode.
///
/// ## Function Parameters
/// * `window`: The window to query.
///
/// ## Return Value
/// Returns true if mouse is grabbed, and false otherwise.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getWindowGrab(
    window: video.Window,
) bool {
    return C.SDL_GetWindowMouseGrab(window.value);
}

/// Get the mouse confinement rectangle of a window
///
/// ## Function Parameters
/// * `window`: The window to query.
///
/// ## Return Value
/// Returns a rectangle to the mouse confinement rectangle of a window, or `null` if there isn't one.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getWindowRect(
    window: video.Window,
) ?rect.IRect {
    const ret = C.SDL_GetWindowMouseRect(window.value);
    if (ret) |val| {
        return rect.IRect.fromSdl(val.*);
    }
    return null;
}

/// Query whether relative mouse mode is enabled for a window.
///
/// ## Function Parameters
/// * `window`: The window to query.
///
/// ## Return Value
/// Returns true if relative mode is enabled for a window or false otherwise.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getWindowRelativeMode(
    window: video.Window,
) bool {
    return C.SDL_GetWindowRelativeMouseMode(window.value);
}

/// Return whether a mouse is currently connected.
///
/// ## Return Value
/// Returns true if a mouse is connected, false otherwise.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn has() bool {
    return C.SDL_HasMouse();
}

/// Hide the cursor.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn hide() !void {
    return errors.wrapCallBool(C.SDL_HideCursor());
}

/// Set the active cursor.
///
/// ## Function Parameters
/// * `cursor`: The cursor to make active.
///
/// ## Remarks
/// This function sets the currently active cursor to the specified one.
/// If the cursor is currently visible, the change will be immediately represented on the display.
/// `mouse.set(null)` can be used to force cursor redraw, if this is desired for any reason.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn set(
    cursor: ?Cursor,
) !void {
    return errors.wrapCallBool(C.SDL_SetCursor(if (cursor) |val| val.value else null));
}

// TODO: ADD THIS WHEN SDL IS UPDATED!
// /// Set a user-defined function by which to transform relative mouse inputs.
// ///
// /// ## Function Parameters
// /// * `callback`: A callback used to transform relative mouse motion, or `null` for default behavior.
// /// * `user_data`: A pointer that will be passed to `callback`.
// ///
// /// ## Remarks
// /// This overrides the relative system scale and relative speed scale hints.
// /// Should be called prior to enabling relative mouse mode, fails otherwise.
// ///
// /// ## Thread Safety
// /// This function should only be called on the main thread.
// ///
// /// ## Version
// /// This function is available since SDL 3.4.0.
// pub fn setRelativeTransform(
//     callback: MotionTransformCallback,
//     user_data: ?*anyopaque,
// ) !void {
//     return errors.wrapCallBool(C.SDL_SetRelativeMouseTransform(callback, user_data));
// }

/// Set a window's mouse grab mode.
///
/// ## Function Parameters
/// * `window`: The window for which the mouse grab mode should be set.
/// * `grabbed`: This is true to grab mouse, and false to release.
///
/// ## Remarks
/// Mouse grab confines the mouse cursor to the window.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn setWindowGrab(
    window: video.Window,
    grabbed: bool,
) !void {
    return errors.wrapCallBool(C.SDL_SetWindowMouseGrab(window.value, grabbed));
}

/// Confines the cursor to the specified area of a window.
///
/// ## Function Parameters
/// * `window`: The window that will be associated with the barrier.
/// * `area`: A rectangle area in window-relative coordinates. If `null` the barrier for the specified window will be destroyed.
///
/// ## Remarks
/// Note that this does **not** grab the cursor, it only defines the area a cursor is restricted to when the window has mouse focus.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn setWindowRect(
    window: video.Window,
    area: ?rect.IRect,
) !void {
    if (area) |val| {
        const c_val = val.toSdl();
        return errors.wrapCallBool(C.SDL_SetWindowMouseRect(window.value, &c_val));
    }
    return errors.wrapCallBool(C.SDL_SetWindowMouseRect(window.value, null));
}

/// Set relative mouse mode for a window.
///
/// ## Function Parameters
/// * `window`: The window to change.
/// * `enabled`: True to enable relative mode, false to disable.
///
/// ## Remarks
/// While the window has focus and relative mouse mode is enabled, the cursor is hidden, the mouse position is constrained to the window,
/// and SDL will report continuous relative mouse motion even if the mouse is at the edge of the window.
///
/// If you'd like to keep the mouse position fixed while in relative mode you can use `mouse.setWindowRect()`.
/// If you'd like the cursor to be at a specific location when relative mode ends, you should use `mouse.warpInWindow()` before disabling relative mode.
///
/// This function will flush any pending mouse motion for this window.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn setWindowRelativeMode(
    window: video.Window,
    enabled: bool,
) !void {
    return errors.wrapCallBool(C.SDL_SetWindowRelativeMouseMode(window.value, enabled));
}

/// Show the cursor.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn show() !void {
    return errors.wrapCallBool(C.SDL_ShowCursor());
}

/// Return whether the cursor is currently being shown.
///
/// ## Return Value
/// Returns true if the cursor is being shown, or false if the cursor is hidden.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn visible() bool {
    return C.SDL_CursorVisible();
}

/// Move the mouse to the given position in global screen space.
///
/// ## Function Parameters
/// * `x`: The x coordinate.
/// * `y`: The y coordinate.
///
/// ## Remarks
/// This function generates a mouse motion event.
///
/// A failure of this function usually means that it is unsupported by a platform.
///
/// Note that this function will appear to succeed, but not actually move the mouse when used over Microsoft Remote Desktop.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn warpGlobal(
    x: f32,
    y: f32,
) !void {
    return errors.wrapCallBool(C.SDL_WarpMouseGlobal(x, y));
}

/// Move the mouse cursor to the given position within the window.
///
/// ## Function parameters
/// * `window`: The window to move the mouse into, or `null` for the current mouse focus.
/// * `x`: The x coordinate within the window.
/// * `y`: The y coordinate within the window.
///
/// ## Remarks
/// This function generates a mouse motion event if relative mode is not enabled.
/// If relative mode is enabled, you can force mouse events for the warp by setting the `hints.Type.mouse_relative_warp_motion` hint.
///
/// Note that this function will appear to succeed, but not actually move the mouse when used over Microsoft Remote Desktop.
///
/// ## Thread Safety
/// This function should only be called on the main thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn warpInWindow(
    window: ?video.Window,
    x: f32,
    y: f32,
) void {
    C.SDL_WarpMouseInWindow(if (window) |val| val.value else null, x, y);
}

// Mouse related tests.
test "Mouse" {
    std.testing.refAllDeclsRecursive(@This());

    defer init.shutdown();
    try init.init(.{ .video = true });
    defer init.quit(.{ .video = true });

    const mice: ?[]ID = getMice() catch null;
    if (mice) |val| {
        for (val) |mouse|
            _ = mouse.getName() catch {};
        stdinc.free(val);
    }

    capture(false) catch {};

    _ = get();
    set(null) catch {};
    _ = has();
    hide() catch {};
    show() catch {};
    _ = visible();

    const cursor1: ?Cursor = Cursor.init(&.{0}, &.{0}, 1, 1, 0, 0) catch null;
    if (cursor1) |val|
        val.deinit();

    const cursor2: ?Cursor = Cursor.initSystem(.pointer) catch null;
    if (cursor2) |val|
        val.deinit();

    _ = getDefault() catch {};
    _ = getGlobalState();
    _ = getFocus();
    // const state = getState();
    _ = getRelativeState();
    // warpGlobal(state.x, state.y) catch {};

    const window: ?video.Window = video.Window.init("Test", 100, 100, .{}) catch null;
    if (window) |val| {
        defer val.deinit();

        const cursor3: ?Cursor = Cursor.initColor(try val.getSurface(), 0, 0) catch null;
        if (cursor3) |cursor|
            cursor.deinit();

        _ = getWindowGrab(val);
        _ = getWindowRect(val);
        _ = getWindowRelativeMode(val);
        setWindowGrab(val, false) catch {};
        setWindowRect(val, null) catch {};
        setWindowRelativeMode(val, false) catch {};
        // warpInWindow(val, state.x, state.y);
    }

    // setRelativeTransform TODO: Test when added!
}
