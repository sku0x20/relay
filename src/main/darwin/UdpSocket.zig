const sys = @import("sys.zig");
const SocketAddress = @import("../SocketAddress.zig");

pub const Receiver = struct {
    ctx: *anyopaque,
    recv: *const fn (ctx: *anyopaque, data: []const u8) void,
};

const UdpSocket = @This();

socket: i32,
addr: sys.SockaddrIn,
receiver: Receiver,

pub fn init(
    socketAddress: SocketAddress,
    receiver: Receiver,
) !UdpSocket {
    const socket = sys.socket(sys.AF.INET, sys.SOCK.DGRAM, 0);
    try check(socket);
    errdefer _ = sys.close(socket);

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
        .receiver = receiver,
    };
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
