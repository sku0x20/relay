const testing = @import("std").testing;

const UdpSocket = @import("../../main/darwin/UdpSocket.zig");
const SocketAddress = @import("../../main/SocketAddress.zig");

const socketAddress: SocketAddress = .{
    .addr = 0x7f000001,
    .port = 0,
};

const NULL_RECEIVER: UdpSocket.Receiver = .{
    .ctx = undefined,
    .recv = struct {
        fn recv(_: *anyopaque, _: []const u8) void {}
    }.recv,
};

test "open and close" {
    const socket = try UdpSocket.init(socketAddress, NULL_RECEIVER);
    try socket.close();
}

test "open with deferred deinit" {
    const socket = try UdpSocket.init(socketAddress, NULL_RECEIVER);
    defer socket.deinit();
}

test "bound to requested port" {
    const socket = try UdpSocket.init(
        .{ .addr = 0x7f000001, .port = 48879 },
        NULL_RECEIVER,
    );
    defer socket.deinit();

    try testing.expectEqual(@byteSwap(@as(u16, 48879)), socket.addr.port);
}
