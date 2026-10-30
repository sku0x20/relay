const sys = @import("sys.zig");
const SocketAddress = @import("../SocketAddress.zig");

const UdpSocket = @This();

socket: i32,
address: SocketAddress,

pub fn init(socketAddress: SocketAddress) !UdpSocket {
    const socket = sys.socket(sys.AF.INET, sys.SOCK.DGRAM, 0);
    try check(socket);
    errdefer _ = sys.close(socket);

    const flags = sys.fcntl(socket, sys.F.GETFL);
    try check(flags);
    try check(sys.fcntl(socket, sys.F.SETFL, flags | sys.O.NONBLOCK));

    var addr = toSockaddr(socketAddress);
    var len: u32 = @sizeOf(sys.SockaddrIn);

    try check(sys.bind(socket, &addr, len));
    try check(sys.getsockname(socket, &addr, &len));

    return .{
        .socket = socket,
        .address = fromSockaddr(addr),
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
    if (datagram.len > datagram.data.len) unreachable;
    const addr = toSockaddr(datagram.peer);
    try check(sys.sendto(self.socket, datagram.data.ptr, datagram.len, 0, &addr, @sizeOf(sys.SockaddrIn)));
}

/// Nonblocking: `error.Again` means no datagram is queued yet; wait until readable and retry.
/// Fills `datagram.data` and sets `len` and `peer`. `data` itself is left as is, so the
/// same Datagram can be reused. A datagram longer than `data` is silently truncated:
/// the rest is discarded, and the next `recv` returns the next datagram. `len == data.len`
/// does not tell truncation from an exact fit; that needs `recvmsg` and `MSG_TRUNC` in `msg_flags`.
pub fn recv(self: *const UdpSocket, datagram: *Datagram) !void {
    var addr: sys.SockaddrIn = undefined;
    var len: u32 = @sizeOf(sys.SockaddrIn);
    const n = sys.recvfrom(self.socket, datagram.data.ptr, datagram.data.len, 0, &addr, &len);
    try check(n);
    datagram.len = @intCast(n);
    datagram.peer = fromSockaddr(addr);
}

pub fn close(self: *const UdpSocket) !void {
    try check(sys.close(self.socket));
}

pub fn deinit(self: *const UdpSocket) void {
    self.close() catch {};
}

inline fn toSockaddr(address: SocketAddress) sys.SockaddrIn {
    return .{
        .port = @byteSwap(address.port),
        .addr = @byteSwap(address.addr),
    };
}

inline fn fromSockaddr(addr: sys.SockaddrIn) SocketAddress {
    return .{
        .addr = @byteSwap(addr.addr),
        .port = @byteSwap(addr.port),
    };
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
