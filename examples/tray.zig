const sdl3 = @import("sdl3");
const std = @import("std");

const State = struct {
    random: std.Random,
    surface: sdl3.surface.Surface,
    quit: bool = false,
};

fn switch_icon_color(user_data: ?*State, entry: sdl3.tray.Entry) void {
    const state = user_data.?;
    const color = sdl3.pixels.FColor{ .r = state.random.float(f32), .g = state.random.float(f32), .b = state.random.float(f32), .a = 1 };
    state.surface.clear(color) catch {};
    entry.getParent().getParentTray().?.setIcon(state.surface);
}

fn toggle_button(user_data: ?*State, entry: sdl3.tray.Entry) void {
    _ = user_data;
    const sub_menu = entry.getParent();
    const button = sub_menu.getEntries()[1];
    if (button.getEnabled()) {
        button.setEnabled(false);
        button.setLabel("Disabled");
    } else {
        button.setEnabled(true);
        button.setLabel("Enabled");
    }
    _ = button.getLabel();
    const main_menu = sub_menu.getParentEntry().?;
    const tray = main_menu.getParent().getParentTray().?;
    tray.setTooltip("Toggled sub-menu checkbox");
}

fn quit(user_data: ?*State, entry: sdl3.tray.Entry) void {
    _ = entry;
    const state = user_data.?;
    state.quit = true;
}

pub fn main() !void {
    defer sdl3.shutdown();

    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    var prng = std.Random.DefaultPrng.init(@bitCast(std.time.microTimestamp()));
    var state = State{
        .surface = try sdl3.surface.Surface.init(32, 32, .array_rgba_32),
        .random = prng.random(),
    };

    // Tray icon.
    try state.surface.clear(.{ .r = 1, .g = 0, .b = 1, .a = 1 });
    defer state.surface.deinit();

    // Create tray and menu.
    const tray = sdl3.tray.Tray.init(state.surface, "SDL3 Tray Example");
    defer tray.deinit();
    const menu = tray.createMenu();
    try std.testing.expectEqual(menu, tray.getMenu());

    // Buttons.
    const checkbox = menu.insertAt(null, "Checkbox", .{ .entry = .{ .checkbox = false } }).?;
    checkbox.setChecked(true);
    try std.testing.expect(checkbox.getChecked());
    checkbox.click();
    try std.testing.expect(!checkbox.getChecked());
    const change_color_button = menu.insertAt(0, "Change Color", .{ .entry = .{ .button = {} } }) orelse return error.SdlError;
    change_color_button.setCallback(State, switch_icon_color, &state);
    _ = menu.insertAt(null, null, .{ .entry = .{ .button = {} } }); // Separator.
    const delete_me = menu.insertAt(null, "DELETE ME", .{ .entry = .{ .button = {} } }).?;
    delete_me.remove();
    const sub_menu = menu.insertAt(0, "Sub Menu", .{ .entry = .{ .submenu = {} } }).?;
    const sub_menu_menu = sub_menu.createSubmenu();
    try std.testing.expectEqual(sub_menu.getSubmenu(), sub_menu_menu);
    const quit_button = menu.insertAt(null, "Quit", .{
        .entry = .{ .button = {} },
    }).?;
    quit_button.setCallback(State, quit, &state);

    // Sub-menu.
    const enable_button = sub_menu_menu.insertAt(null, "Enable Button", .{ .entry = .{ .checkbox = false } }).?;
    enable_button.setCallback(State, toggle_button, &state);
    _ = sub_menu_menu.insertAt(null, "Disabled", .{ .disabled = true, .entry = .{ .button = {} } });

    while (!state.quit) {
        sdl3.tray.update();
        const event = sdl3.events.waitAndPopTimeout(200) orelse continue;
        switch (event) {
            .terminating => break,
            .quit => break,
            else => {},
        }
    }
}
