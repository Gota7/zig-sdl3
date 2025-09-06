const c = @import("c");
const errors = @import("errors.zig");
const std = @import("std");

/// The current major version of SDL_net headers.
pub const major_version = c.SDL_NET_MAJOR_VERSION;

/// The current minor version of the SDL_net headers.
pub const minor_version = c.SDL_NET_MINOR_VERSION;

/// The current micro (or patchlevel) version of the SDL_net headers.
pub const micro_version = c.SDL_NET_MICRO_VERSION;

/// This function gets the version of the dynamically linked SDL_net library.
///
/// ## Return Value
/// Returns SDL_net version.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn getVersion() std.SemanticVersion {
    // TODO use NET_Version()
    return .{
        .major = major_version,
        .minor = minor_version,
        .patch = micro_version,
    };
}

/// Initialize the SDL_net library.
///
/// ## Remarks
/// This must be successfully called once before (almost) any other SDL_net function can be used.
/// It is safe to call this multiple times; the library will only initialize once, and won't deinitialize until `net.quit()` has been called a matching number of times.
/// Extra attempts to init report success.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn init() Error!void {
    return errors.wrapCallBool(c.NET_Init());
}

/// Deinitialize the SDL_net library.
///
/// ## Remarks
/// This must be called when done with the library, probably at the end of your program.
/// It is safe to call this multiple times; the library will only deinitialize once, when this function is called the same number of times as `net.init()` was successfully called.
/// Once you have successfully deinitialized the library, it is safe to call `net.init()` to reinitialize it for further use.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn quit() void {
    c.NET_Quit();
}

/// Error, set by a network operation.
///
/// ## Version
/// This error is provided by zig-sdl3.
pub const Error = error{
    SdlNetError,
    SdlError,
    OutOfMemory,
};

/// Specifies a timeout for a network operation.
///
/// ## Version
/// This type is provided by zig-sdl3.
pub const Timeout = union(enum) {
    /// Wait indefinitely.
    indefinite,
    /// Do not wait, check once and return immediately.
    no_wait,
    /// Wait for a specific number of milliseconds.
    milliseconds: u32,

    /// Convert to an SDL i32 value.
    pub fn toSdl(self: Timeout) i32 {
        return switch (self) {
            .indefinite => -1,
            .no_wait => 0,
            .milliseconds => |ms| @intCast(ms),
        };
    }
};

/// Opaque representation of a computer-readable network address.
///
/// ## Remarks
/// This is an opaque datatype, to be treated by the app as a handle.
/// SDL_net uses these to identify other servers; you use them to connect to a remote machine, and you use them to find out who connected to you.
/// They are also used to decide what network interface to use when creating a server.
/// These are intended to be protocol-independent; a given address might be for IPv4, IPv6, or something more esoteric.
/// SDL_net attempts to hide the differences.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const Address = packed struct {
    value: *c.NET_Address,

    /// Status of an address resolution.
    pub const Status = enum {
        resolved,
        resolving,
    };

    /// Resolve a human-readable hostname.
    ///
    /// ## Function Parameters
    /// * `host`: The hostname to resolve.
    ///
    /// ## Return Value
    /// Returns a new address on success.
    ///
    /// ## Remarks
    /// SDL_net doesn't operate on human-readable hostnames (like `www.libsdl.org`) but on computer-readable addresses.
    /// This function converts from one to the other. This process is known as "resolving" an address.
    /// You can also use this to turn IP address strings (like "159.203.69.7") into `net.Address` objects.
    /// Note that resolving an address is an asynchronous operation, since the library will need to ask a server on the internet to get the information it needs, and this can take time (and possibly fail later).
    /// This function will not block. It either returns an error (catastrophic failure) or an unresolved `net.Address`.
    /// Until the address resolves, it can't be used.
    /// If you want to block until the resolution is finished, you can call `net.Address.waitUntilResolved()`.
    /// Otherwise, you can do a non-blocking check with `net.Address.getStatus()`.
    /// When you are done with the returned `net.Address`, call `deinit()` to dispose of it.
    /// You need to do this even if resolution later fails asynchronously.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn init(host: [:0]const u8) Error!Address {
        return .{
            .value = try errors.wrapCallNull(*c.NET_Address, c.NET_ResolveHostname(host.ptr)),
        };
    }

    /// Drop a reference to an `net.Address`.
    ///
    /// ## Function Parameters
    /// * `self`: The address to deinitialize.
    ///
    /// ## Remarks
    /// Since several pieces of the library might share a single `net.Address`, including a background thread that's working on resolving, these objects are referenced counted.
    /// This allows everything that's using it to declare they still want it, and drop their reference to the address when they are done with it.
    /// The object's resources are freed when the last reference is dropped.
    /// This function drops a reference to an `net.Address`, decreasing its reference count by one.
    /// The documentation will tell you when the app has to explicitly unref an address.
    /// For example, `net.Address.init()` creates addresses that are already referenced, so the caller needs to call `deinit()` when done.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(self: Address) void {
        c.NET_UnrefAddress(self.value);
    }

    /// Add a reference to an `net.Address`.
    ///
    /// ## Function Parameters
    /// * `self`: The address to add a reference to.
    ///
    /// ## Return Value
    /// Returns the same address that was passed as a parameter.
    ///
    /// ## Remarks
    /// Since several pieces of the library might share a single `net.Address`, these objects are referenced counted.
    /// This function adds a reference to an `net.Address`, increasing its reference count by one.
    /// Generally you only have to explicit ref an address when you have different parts of your own app that will be sharing an address.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn ref(self: Address) Address {
        return .{ .value = c.NET_RefAddress(self.value) };
    }

    /// Block until an address is resolved.
    ///
    /// ## Function Parameters
    /// * `self`: The address object to wait on.
    /// * `timeout`: The maximum time to wait for resolution to complete.
    ///
    /// ## Return Value
    /// Returns `true` if successfully resolved, `false` if the timeout was reached.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread, and several threads can block on the same address simultaneously.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn waitUntilResolved(self: Address, timeout: Timeout) Error!bool {
        const ret = c.NET_WaitUntilResolved(self.value, timeout.toSdl());
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return ret == 1;
    }

    /// Check if an address is resolved, without blocking.
    ///
    /// ## Function Parameters
    /// * `self`: The address to query.
    ///
    /// ## Return Value
    /// Returns `net.Address.Status.resolved` if successfully resolved, `net.Address.Status.resolving` if still resolving.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getStatus(self: Address) Error!Status {
        const ret = c.NET_GetAddressStatus(self.value);
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return if (ret == 1) .resolved else .resolving;
    }

    /// Get a human-readable string from a resolved address.
    ///
    /// ## Function Parameters
    /// * `self`: The address to query.
    ///
    /// ## Return Value
    /// Returns a string, or `null` on error or if not yet resolved.
    ///
    /// ## Remarks
    /// The returned string is owned by the `net.Address` and is valid as long as the object lives.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getString(self: Address) ?[:0]const u8 {
        const ret = c.NET_GetAddressString(self.value);
        if (ret == null) return null;
        return std.mem.sliceTo(ret, 0);
    }

    /// Compare two `net.Address` objects.
    ///
    /// ## Function Parameters
    /// * `self`: The first address to compare.
    /// * `other`: second address to compare.
    ///
    /// ## Return Value
    /// Returns `std.math.Order.lt` if `self` is "less than" `other`, `std.math.Order.gt` if "greater than", `std.math.Order.eq` if equal.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn compare(self: Address, other: Address) std.math.Order {
        return std.math.order(c.NET_CompareAddresses(self.value, other.value), 0);
    }

    comptime {
        std.debug.assert(@sizeOf(Address) == @sizeOf(*c.NET_Address));
    }
};

/// Enable simulated address resolution failures.
///
/// ## Function Parameters
/// * `percent_loss`: A number between 0 and 100. Higher means more failures. Zero to disable.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn simulateAddressResolutionLoss(percent_loss: u8) void {
    std.debug.assert(percent_loss <= 100);
    c.NET_SimulateAddressResolutionLoss(@intCast(percent_loss));
}

/// A list of local addresses returned by `getLocalAddresses`.
///
/// ## Version
/// This struct is provided by zig-sdl3.
pub const LocalAddressList = struct {
    slice: []const Address,

    /// Free the list of local addresses.
    ///
    /// ## Function Parameters
    /// * `self`: The list to deinitialize.
    ///
    /// ## Remarks
    /// This will unref all addresses in the list and free the list itself.
    /// It is safe to keep any addresses you want from this list even after calling this function, as long as you called `ref()` on them first.
    pub fn deinit(self: LocalAddressList) void {
        c.NET_FreeLocalAddresses(@ptrCast(self.slice.ptr));
    }
};

/// Obtain a list of local addresses on the system.
///
/// ## Return Value
/// Returns a list of `net.Address` objects, one for each bindable address on the system.
/// The caller must call `deinit()` on the returned list when done with it.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn getLocalAddresses() Error!LocalAddressList {
    var num_addresses: c_int = 0;
    const addresses_c = c.NET_GetLocalAddresses(&num_addresses);
    if (addresses_c == null) {
        errors.callErrorCallback();
        return error.SdlNetError;
    }

    return .{ .slice = @as([*]const Address, @ptrCast(addresses_c))[0..@intCast(num_addresses)] };
}

/// An object that represents a streaming connection to another system.
///
/// ## Remarks
/// This is meant to be a reliable, stream-oriented connection, such as TCP.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const StreamSocket = struct {
    value: *c.NET_StreamSocket,

    /// Status of a stream socket connection.
    ///
    /// ## Version
    /// This enum is available since SDL_net 3.0.0.
    pub const ConnectionStatus = enum {
        connected,
        connecting,
    };

    /// Begin connecting a socket as a client to a remote server.
    ///
    /// ## Function Parameters
    /// * `address`: the address of the remote server to connect to.
    /// * `port`: the port on the remote server to connect to.
    ///
    /// ## Return Value
    /// Returns a new `net.StreamSocket`, pending connection.
    ///
    /// ## Remarks
    /// Connecting is an asynchronous operation; this function does not block.
    /// When you are done with this connection, you must dispose of it with `deinit()`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn initClient(address: Address, port: u16) Error!StreamSocket {
        return .{
            .value = try errors.wrapCallNull(*c.NET_StreamSocket, c.NET_CreateClient(address.value, port)),
        };
    }

    /// Dispose of a previously-created stream socket.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to destroy.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(self: StreamSocket) void {
        c.NET_DestroyStreamSocket(self.value);
    }

    /// Block until a stream socket has connected to a server.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket object to wait on.
    /// * `timeout`: The maximum time to wait for connection to complete.
    ///
    /// ## Return Value
    /// Returns `true` if successfully connected, `false` if still connecting (this function timed out).
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn waitUntilConnected(self: StreamSocket, timeout: Timeout) Error!bool {
        const ret = c.NET_WaitUntilConnected(self.value, timeout.toSdl());
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return ret == 1;
    }

    /// Get the remote address of a stream socket.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to query.
    ///
    /// ## Return Value
    /// Returns the socket's remote address. The caller must call `deinit()` on the returned address.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getAddress(self: StreamSocket) Error!Address {
        return .{
            .value = try errors.wrapCallNull(*c.NET_Address, c.NET_GetStreamSocketAddress(self.value)),
        };
    }

    /// Check if a stream socket is connected, without blocking.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to query.
    ///
    /// ## Return Value
    /// Returns `net.StreamSocket.ConnectionStatus.connected` if successfully connected, or `net.StreamSocket.ConnectionStatus.connecting` if still connecting.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getConnectionStatus(self: StreamSocket) Error!ConnectionStatus {
        const ret = c.NET_GetConnectionStatus(self.value);
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return if (ret == 1) .connected else .connecting;
    }

    /// Send bytes over a stream socket to a remote system.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to send data through.
    /// * `data`: the data to send.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn write(self: StreamSocket, data: []const u8) Error!void {
        return errors.wrapCallBool(c.NET_WriteToStreamSocket(self.value, data.ptr, @intCast(data.len)));
    }

    /// Query bytes still pending transmission on a stream socket.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to query.
    ///
    /// ## Return Value
    /// Returns number of bytes still pending transmission.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn getPendingWrites(self: StreamSocket) Error!usize {
        const ret = c.NET_GetStreamSocketPendingWrites(self.value);
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return @intCast(ret);
    }

    /// Block until all of a stream socket's pending data is sent.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to wait on.
    /// * `timeout`: The maximum time to wait for draining to complete.
    ///
    /// ## Return Value
    /// Returns number of bytes still pending transmission.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn waitUntilDrained(self: StreamSocket, timeout: Timeout) Error!usize {
        const ret = c.NET_WaitUntilStreamSocketDrained(self.value, timeout.toSdl());
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return @intCast(ret);
    }

    /// Receive bytes that a remote system sent to a stream socket.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to receive data from.
    /// * `buf`: a buffer where received data will be collected.
    ///
    /// ## Return Value
    /// Returns number of bytes read from the stream socket (which can be less than `buf.len` or zero if none available).
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn read(self: StreamSocket, buf: []u8) Error!usize {
        const ret = c.NET_ReadFromStreamSocket(self.value, buf.ptr, @intCast(buf.len));
        if (ret < 0) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        return @intCast(ret);
    }

    /// Enable simulated stream socket failures.
    ///
    /// ## Function Parameters
    /// * `self`: The stream socket to set a failure rate on.
    /// * `percent_loss`: A number between 0 and 100. Higher means more failures. Zero to disable.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn simulatePacketLoss(self: StreamSocket, percent_loss: u8) void {
        std.debug.assert(percent_loss <= 100);
        c.NET_SimulateStreamPacketLoss(self.value, @intCast(percent_loss));
    }
};

/// The receiving end of a stream connection.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const Server = struct {
    value: *c.NET_Server,

    /// Create a server, which listens for connections to accept.
    ///
    /// ## Function Parameters
    /// * `addr`: the _local_ address to listen for connections on, or `null`.
    /// * `port`: the port on the local address to listen for connections on.
    ///
    /// ## Return Value
    /// Returns a new `net.Server`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn init(addr: ?Address, port: u16) Error!Server {
        const addr_ptr = if (addr) |a| a.value else null;
        return .{
            .value = try errors.wrapCallNull(*c.NET_Server, c.NET_CreateServer(addr_ptr, port)),
        };
    }

    /// Dispose of a previously-created server.
    ///
    /// ## Function Parameters
    /// * `self`: The server to destroy.
    ///
    /// ## Thread Safety
    /// You should not operate on the same server from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(self: Server) void {
        c.NET_DestroyServer(self.value);
    }

    /// Create a stream socket for the next pending client connection.
    ///
    /// ## Function Parameters
    /// * `self`: The server to check for pending connections.
    ///
    /// ## Return Value
    /// Returns a new stream socket if a connection was pending, `null` otherwise.
    ///
    /// ## Thread Safety
    /// You should not operate on the same server from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn accept(self: Server) Error!?StreamSocket {
        var client_stream: ?*c.NET_StreamSocket = null;
        if (!c.NET_AcceptClient(self.value, &client_stream)) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        if (client_stream) |ptr| {
            return StreamSocket{ .value = ptr };
        } else {
            return null;
        }
    }
};

/// The data provided for new incoming packets from `net.DatagramSocket.receive()`.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const Datagram = struct {
    value: *c.NET_Datagram,

    /// Dispose of a datagram packet previously received.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram to destroy.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(self: Datagram) void {
        c.NET_DestroyDatagram(self.value);
    }

    /// Get the address of the sender.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram to get the address from.
    ///
    /// ## Remarks
    /// The returned address is owned by the datagram. If you want to keep it after `deinit()`ing the datagram, you must `ref()` it.
    pub fn getAddress(self: Datagram) Address {
        return .{ .value = self.value.addr };
    }

    /// Get the port of the sender.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram to get the port from.
    ///
    /// ## Remarks
    /// The port is in host byte order and does not need to be byteswapped.
    pub fn getPort(self: Datagram) u16 {
        return self.value.port;
    }

    /// Get the data payload of the datagram.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram to get the data from.
    ///
    /// ## Remarks
    /// The returned slice is owned by the datagram and is valid until `deinit()` is called.
    pub fn getData(self: Datagram) []const u8 {
        return self.value.buf[0..@intCast(self.value.buflen)];
    }
};

/// An object that represents a datagram connection to another system.
///
/// ## Remarks
/// This is meant to be an unreliable, packet-oriented connection, such as UDP.
///
/// ## Version
/// This datatype is available since SDL_net 3.0.0.
pub const DatagramSocket = struct {
    value: *c.NET_DatagramSocket,

    /// Create and bind a new datagram socket.
    ///
    /// ## Function Parameters
    /// * `addr`: the local address to listen for connections on, or `null` to listen on all available local addresses.
    /// * `port`: the port on the local address to listen for connections on, or zero for the system to decide.
    ///
    /// ## Return Value
    /// Returns a new `net.DatagramSocket`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn init(addr: ?Address, port: u16) Error!DatagramSocket {
        const addr_ptr = if (addr) |a| a.value else null;
        return .{
            .value = try errors.wrapCallNull(*c.NET_DatagramSocket, c.NET_CreateDatagramSocket(addr_ptr, port)),
        };
    }

    /// Dispose of a previously-created datagram socket.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram socket to destroy.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn deinit(self: DatagramSocket) void {
        c.NET_DestroyDatagramSocket(self.value);
    }

    /// Send a new packet over a datagram socket to a remote system.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram socket to send data through.
    /// * `address`: the destination address.
    /// * `port`: the destination port.
    /// * `data`: a pointer to the data to send as a single packet.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn send(self: DatagramSocket, address: Address, port: u16, data: []const u8) Error!void {
        return errors.wrapCallBool(c.NET_SendDatagram(self.value, address.value, port, data.ptr, @intCast(data.len)));
    }

    /// Receive a new packet that a remote system sent to a datagram socket.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram socket to receive data from.
    ///
    /// ## Return Value
    /// Returns a new datagram packet if one was available, `null` otherwise.
    /// The caller must call `deinit()` on the returned datagram when done with it.
    ///
    /// ## Thread Safety
    /// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn receive(self: DatagramSocket) Error!?Datagram {
        var dgram: ?*c.NET_Datagram = null;
        if (!c.NET_ReceiveDatagram(self.value, &dgram)) {
            errors.callErrorCallback();
            return error.SdlNetError;
        }
        if (dgram) |ptr| {
            return Datagram{ .value = ptr };
        } else {
            return null;
        }
    }

    /// Enable simulated datagram socket failures.
    ///
    /// ## Function Parameters
    /// * `self`: The datagram socket to set a failure rate on.
    /// * `percent_loss`: A number between 0 and 100. Higher means more failures. Zero to disable.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_net 3.0.0.
    pub fn simulatePacketLoss(self: DatagramSocket, percent_loss: u8) void {
        std.debug.assert(percent_loss <= 100);
        c.NET_SimulateDatagramPacketLoss(self.value, @intCast(percent_loss));
    }
};

/// A socket that can be polled for input.
///
/// ## Version
/// This type is provided by zig-sdl3.
pub const Pollable = union(enum) {
    server: Server,
    stream: StreamSocket,
    datagram: DatagramSocket,

    fn toOpaque(self: Pollable) ?*anyopaque {
        return switch (self) {
            .server => |s| s.value,
            .stream => |s| s.value,
            .datagram => |s| s.value,
        };
    }
};

/// Block on multiple sockets until at least one has data available.
///
/// ## Function Parameters
/// * `allocator`: The allocator to use for temporary storage.
/// * `sockets`: an array of `net.Pollable` sockets to wait on.
/// * `timeout`: The maximum time to wait for new input to become available.
///
/// ## Return Value
/// Returns the number of items that have new input.
///
/// ## Thread Safety
/// You should not operate on the same socket from multiple threads at the same time without supplying a serialization mechanism.
///
/// ## Version
/// This function is available since SDL_net 3.0.0.
pub fn waitUntilInputAvailable(allocator: std.mem.Allocator, sockets: []const Pollable, timeout: Timeout) Error!usize {
    if (sockets.len == 0) return 0;

    var c_sockets = try allocator.alloc(?*anyopaque, sockets.len);
    defer allocator.free(c_sockets);

    for (sockets, 0..) |s, i| {
        c_sockets[i] = s.toOpaque();
    }

    const ret = c.NET_WaitUntilInputAvailable(@ptrCast(c_sockets.ptr), @intCast(c_sockets.len), timeout.toSdl());
    if (ret < 0) {
        errors.callErrorCallback();
        return error.SdlNetError;
    }
    return @intCast(ret);
}

test "net" {
    std.testing.refAllDeclsRecursive(@This());
}
