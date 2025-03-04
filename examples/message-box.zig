const sdl3 = @import("sdl3");

fn playGame() !bool {
    const val = try sdl3.message_box.show(
        .{},
        "Question:",
        "What is my favorite color?",
        null,
        [_]sdl3.message_box.Button{ sdl3.message_box.Button{
            .text = "Red",
            .value = 0,
        }, sdl3.message_box.Button{
            .text = "Orange",
            .value = 0,
        }, sdl3.message_box.Button{
            .text = "Yellow",
            .value = 0,
        }, sdl3.message_box.Button{
            .text = "Green",
            .value = 0,
        }, sdl3.message_box.Button{
            .text = "Blue",
            .value = 0,
        }, sdl3.message_box.Button{
            .text = "Purple",
            .value = 1,
        } },
        null,
    );
    if (val != 1) {
        _ = try sdl3.message_box.show(
            .{ .error_dialog = true },
            "Wrong!",
            "You have chosen the wrong answer. Please try again.",
            null,
            [_]sdl3.message_box.Button{
                sdl3.message_box.Button{
                    .text = "I Understand",
                    .value = 0,
                },
            },
            .{
                .background = sdl3.message_box.Color{ .r = 10, .g = 10, .b = 10 },
                .text = try sdl3.message_box.Color.fromHex("ffffff"),
                .button_border = .{ .r = 75, .g = 55, .b = 50 },
                .button_background = sdl3.message_box.Color{ .r = 160, .g = 20, .b = 20 },
                .button_selected = try sdl3.message_box.Color.fromHex("fdfd22"),
            },
        );
        return false;
    } else {
        _ = try sdl3.message_box.show(
            .{ .information_dialog = true },
            "Correct!",
            "You have guessed correctly. Yippee!",
            null,
            [_]sdl3.message_box.Button{
                sdl3.message_box.Button{
                    .text = "Bye!",
                    .value = 0,
                },
            },
            .{
                .background = sdl3.message_box.Color{ .r = 195, .g = 195, .b = 195 },
                .text = try sdl3.message_box.Color.fromHex("660aa8"),
                .button_border = .{ .r = 50, .g = 75, .b = 55 },
                .button_background = sdl3.message_box.Color{ .r = 20, .g = 160, .b = 20 },
                .button_selected = try sdl3.message_box.Color.fromHex("fdfd22"),
            },
        );
        return true;
    }
}

pub fn main() !void {
    try sdl3.message_box.showSimple(.{}, "Start!", "Get ready to play the game.", null);
    while (true) {
        if (try playGame())
            break;
    }
}
