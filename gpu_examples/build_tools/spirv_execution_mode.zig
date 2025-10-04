const std = @import("std");

const buf_size = 1024;

const Error = error{
    BadArgCount,
    UnrecognizedArg,
};

const DepthReplacing = void;
const LocalSize = struct {
    x: u32,
    y: u32,
    z: u32,
};

fn usage(err: Error) !void {
    var buf1: [buf_size]u8 = undefined;
    var buf2: [buf_size]u8 = undefined;
    var err_writer = std.fs.File.stderr().writer(&buf1).interface;
    var out_writer = std.fs.File.stdout().writer(&buf2).interface;
    switch (err) {
        error.BadArgCount => try err_writer.writeAll("Invalid arguments specified"),
        error.UnrecognizedArg => try err_writer.writeAll("Unrecognized argument"),
    }
    try out_writer.writeAll("Usage: spirv-execution-mode <input.spvasm> <output.spvasm> [DepthReplacing] [LocalSize x y z]");
    try out_writer.flush();
    return err;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Gather parameters.
    var depth_replacing: ?DepthReplacing = null;
    var local_size: ?LocalSize = null;
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();
    const input_file = args.next() orelse return usage(error.BadArgCount);
    const output_file = args.next() orelse return usage(error.BadArgCount);
    while (args.next()) |execution_mode| {
        if (std.mem.eql(u8, execution_mode, "DepthReplacing")) {
            depth_replacing = {};
        } else if (std.mem.eql(u8, execution_mode, "LocalSize")) {
            const x = args.next() orelse return usage(error.BadArgCount);
            const y = args.next() orelse return usage(error.BadArgCount);
            const z = args.next() orelse return usage(error.BadArgCount);
            local_size = .{
                .x = try std.fmt.parseInt(u32, x, 10),
                .y = try std.fmt.parseInt(u32, y, 10),
                .z = try std.fmt.parseInt(u32, z, 10),
            };
        } else return usage(error.UnrecognizedArg);
    }

    // Output modified source.
    var read_buf: [buf_size]u8 = undefined;
    var write_buf: [buf_size]u8 = undefined;
    var in_file = try std.fs.cwd().openFile(input_file, .{});
    defer in_file.close();
    var out_file = try std.fs.cwd().createFile(output_file, .{});
    defer out_file.close();
    var f_reader = in_file.reader(&read_buf);
    const reader = &f_reader.interface;
    var f_writer = out_file.writer(&write_buf);
    const writer = &f_writer.interface;
    while (true) {
        const line = reader.takeDelimiterInclusive('\n') catch |err| {
            switch (err) {
                error.EndOfStream => break,
                else => return err,
            }
        };
        try writer.writeAll(line);
        var toks = std.mem.tokenizeScalar(u8, line, ' ');
        const op = toks.next() orelse continue;
        if (!std.mem.eql(u8, op, "OpEntryPoint"))
            continue;
        _ = toks.next();
        const entry_point_var = toks.next() orelse continue;
        if (depth_replacing != null) {
            try writer.writeAll("               OpExecutionMode ");
            try writer.writeAll(entry_point_var);
            try writer.writeAll(" DepthReplacing\n");
        }
        // TODO: LOCAL SIZE SUPPORT!
    }
    try writer.flush();
}
