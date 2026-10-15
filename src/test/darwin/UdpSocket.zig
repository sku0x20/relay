const testing = @import("std").testing;

const UdpSocket = @import("../../main/darwin/UdpSocket.zig");
const SocketAddress = @import("../../main/SocketAddress.zig");

const socketAddress: SocketAddress = .{
    .addr = 0x7f000001,
    .port = 0,
};

test "open and close" {
    const socket = try UdpSocket.init(socketAddress);
    try socket.close();
}

test "open with deferred deinit" {
    const socket = try UdpSocket.init(socketAddress);
    defer socket.deinit();
}

test "bound to requested port" {
    const socket = try UdpSocket.init(.{ .addr = 0x7f000001, .port = 48879 });
    defer socket.deinit();

    try testing.expectEqual(@byteSwap(@as(u16, 48879)), socket.addr.port);
}
