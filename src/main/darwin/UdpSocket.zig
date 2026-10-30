const sys = @import("sys.zig");
const SocketAddress = @import("../SocketAddress.zig");

const UdpSocket = @This();

socket: i32,
addr: sys.SockaddrIn,

pub fn init(socketAddress: SocketAddress) !UdpSocket {
    const socket = sys.socket(sys.AF.INET, sys.SOCK.DGRAM, 0);
    try check(socket);
    errdefer _ = sys.close(socket);

    const flags = sys.fcntl(socket, sys.F.GETFL);
    try check(flags);
    try check(sys.fcntl(socket, sys.F.SETFL, flags | sys.O.NONBLOCK));

    var addr: sys.SockaddrIn = .{
        .port = @byteSwap(socketAddress.port),
        .addr = @byteSwap(socketAddress.addr),
    };
    var len: u32 = @sizeOf(sys.SockaddrIn);

    try check(sys.bind(socket, &addr, len));
    try check(sys.getsockname(socket, &addr, &len));

    return .{
        .socket = socket,
        .addr = addr,
    };
}

pub const Datagram = struct {
    data: []u8,
    len: usize,
    peer: SocketAddress,
};

// TODO: tell the caller when the socket is writable again, so it can retry.

/// Nonblocking: `error.Again` means the kernel had no room and the datagram was not sent.
/// It is not queued or retried; the caller decides whether to drop or retry.
/// UDP is lossy anyway, so dropping is usually fine, and a queue here would
/// need memory limits and write-ready events for a case that rarely happens.
pub fn send(self: *const UdpSocket, datagram: *const Datagram) !void {
    const addr: sys.SockaddrIn = .{
        .port = @byteSwap(datagram.peer.port),
        .addr = @byteSwap(datagram.peer.addr),
    };
    try check(sys.sendto(self.socket, datagram.data.ptr, datagram.len, 0, &addr, @sizeOf(sys.SockaddrIn)));
}

pub fn recv(self: *const UdpSocket, datagram: *Datagram) !void {
    _ = self;
    _ = datagram;
    return error.Unimplemented;
}

pub fn close(self: *const UdpSocket) !void {
    try check(sys.close(self.socket));
}

pub fn deinit(self: *const UdpSocket) void {
    self.close() catch {};
}

fn check(rc: anytype) !void {
    return switch (sys.errno(rc)) {
        .SUCCESS => {},
        .NOENT => error.NoEnt,
        .BADF => error.BadF,
        .PIPE => error.Pipe,
        .AGAIN => error.Again,
        .ADDRINUSE => error.AddrInUse,
        _ => error.Unexpected,
    };
}
