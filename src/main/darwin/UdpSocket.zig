const sys = @import("sys.zig");
const mem = @import("std").mem;

const SocketAddress = @import("../SocketAddress.zig");

const UdpSocket = @This();

socket: i32,
addr: sys.SockaddrIn,

pub fn init(socketAddress: SocketAddress) !UdpSocket {
    const socket = sys.socket(sys.AF.INET, sys.SOCK.DGRAM, 0);
    try check(socket);
    errdefer _ = sys.close(socket);

    var addr: sys.SockaddrIn = .{
        .port = socketAddress.port,
        .addr = mem.nativeToBig(u32, socketAddress.addr),
    };
    var len: u32 = @sizeOf(sys.SockaddrIn);

    try check(sys.bind(socket, &addr, len));
    try check(sys.getsockname(socket, &addr, &len));

    return .{
        .socket = socket,
        .addr = addr,
    };
}

pub fn close(self: UdpSocket) !void {
    try check(sys.close(self.socket));
}

pub fn deinit(self: UdpSocket) void {
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
