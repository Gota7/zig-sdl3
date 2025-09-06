const sdl3 = @import("sdl3");
const std = @import("std");

/// https://en.wikipedia.org/wiki/Ephemeral_port
/// > suggested by RFC 6335 and the Internet Assigned Numbers Authority (IANA) for dynamic or private ports. FreeBSD has used the IANA port range since release 4.6. Windows Vista, Windows 7, and Server 2008 use the IANA range by default.
const iana_dynamic_port_start: u16 = 49152;
const iana_dynamic_port_end: u16 = 65535;
/// Timeout in milliseconds for network operations that might block.
const timeout_ms: u32 = 5000;
const server_poll_timeout_ms: u32 = 100;
const recv_buffer_size = 1024;

var server_should_stop: bool = false;
var server_ready_sem = std.Thread.Semaphore{ .permits = 0 };

fn serverThread(allocator: std.mem.Allocator, log_server: sdl3.log.Category, sem: *std.Thread.Semaphore, port: u16) !void {
    const server: sdl3.net.Server = try .init(null, port);
    defer server.deinit();
    try log_server.logInfo("Server: Listening on port {d}", .{port});

    // Signal that the server is ready to accept connections.
    sem.post();

    while (!server_should_stop) {
        const sockets = &.{sdl3.net.Pollable{ .server = server }};
        const num_ready = try sdl3.net.waitUntilInputAvailable(allocator, sockets, .{ .milliseconds = server_poll_timeout_ms });
        if (num_ready > 0) {

            // A client is trying to connect.
            if (try server.accept()) |client_socket| {
                defer client_socket.deinit();

                const client_addr = try client_socket.getAddress();
                defer client_addr.deinit();

                try log_server.logInfo("Server: Client connected from {s}", .{client_addr.getString() orelse "unknown"});

                // Wait for the client to send us a message.
                const num_client_ready = try sdl3.net.waitUntilInputAvailable(allocator, &.{sdl3.net.Pollable{ .stream = client_socket }}, .indefinite);

                if (num_client_ready > 0) {
                    var buffer: [recv_buffer_size]u8 = undefined;
                    const bytes_read = try client_socket.read(&buffer);

                    if (bytes_read > 0) {
                        try log_server.logInfo("Server: Received '{s}'", .{buffer[0..bytes_read]});

                        // Send a reply.
                        try client_socket.write("Hello from server!");

                        // Wait until the data is sent before we risk closing the socket via defer.
                        _ = try client_socket.waitUntilDrained(.{ .milliseconds = timeout_ms });
                        try log_server.logInfo("Server: Sent reply.", .{});
                    } else {
                        try log_server.logInfo("Server: Client disconnected.", .{});
                    }
                } else {
                    try log_server.logWarn("Server: Timed out waiting for data from client.", .{});
                }
            }
        }
    }
    try log_server.logInfo("Server: Shutting down.", .{});
}

fn clientThread(allocator: std.mem.Allocator, log_client: sdl3.log.Category, port: u16) !void {
    const address: sdl3.net.Address = try .init("127.0.0.1");
    defer address.deinit();

    try log_client.logInfo("Client: Resolving '127.0.0.1'", .{});
    if (!try address.waitUntilResolved(.{ .milliseconds = timeout_ms })) {
        try log_client.logError("Client: Failed to resolve '127.0.0.1'.", .{});
        return;
    }
    try log_client.logInfo("Client: Resolved to {s}", .{address.getString() orelse "unknown"});

    // Connect to the server.
    const client_socket: sdl3.net.StreamSocket = try .initClient(address, port);
    defer client_socket.deinit();

    try log_client.logInfo("Client: Connecting", .{});
    if (!try client_socket.waitUntilConnected(.{ .milliseconds = timeout_ms })) {
        try log_client.logError("Client: Failed to connect to server.", .{});
        return;
    }
    try log_client.logInfo("Client: Connected", .{});

    // Send a message.
    try client_socket.write("Hello from client!");
    try log_client.logInfo("Client: Sent message.", .{});

    // Wait for a reply.
    const num_ready = try sdl3.net.waitUntilInputAvailable(allocator, &.{sdl3.net.Pollable{ .stream = client_socket }}, .{ .milliseconds = timeout_ms });

    if (num_ready > 0) {
        var buffer: [recv_buffer_size]u8 = undefined;
        const bytes_read = try client_socket.read(&buffer);

        if (bytes_read > 0) {
            try log_client.logInfo("Client: Received '{s}'", .{buffer[0..bytes_read]});
        } else {
            try log_client.logInfo("Client: Server closed connection.", .{});
        }
    } else {
        try log_client.logWarn("Client: Timed out waiting for a reply.", .{});
    }
    try log_client.logInfo("Client: Shutting down.", .{});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    try sdl3.init(.{});
    defer sdl3.quit(.{});
    try sdl3.net.init();
    defer sdl3.net.quit();

    const log_server: sdl3.log.Category = @enumFromInt(@intFromEnum(sdl3.log.Category.custom) + 0);
    const log_client: sdl3.log.Category = @enumFromInt(@intFromEnum(sdl3.log.Category.custom) + 1);

    log_server.setPriority(.verbose);
    log_client.setPriority(.verbose);

    var prng: std.Random.DefaultPrng = .init(blk: {
        var seed: u64 = undefined;
        std.crypto.random.bytes(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    const port_range = iana_dynamic_port_end - iana_dynamic_port_start;
    const port = rand.uintAtMost(u16, port_range) + iana_dynamic_port_start;

    try sdl3.log.log("SDL_net version: {any}", .{sdl3.net.getVersion()});

    var server_thread: std.Thread = try .spawn(.{}, serverThread, .{ allocator, log_server, &server_ready_sem, port });

    // Wait for the server to signal that it's ready before starting the client.
    server_ready_sem.wait();
    var client_thread: std.Thread = try .spawn(.{}, clientThread, .{ allocator, log_client, port });

    client_thread.join();
    server_should_stop = true;
    server_thread.join();

    try sdl3.log.log("Example finished.", .{});
}
