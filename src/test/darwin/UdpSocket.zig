const testing = @import("std").testing;
const sys = @import("../../main/darwin/sys.zig");

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

test "datagram delivered by send" {
    const peer = sys.socket(sys.AF.INET, sys.SOCK.DGRAM, 0);
    defer _ = sys.close(peer);

    var addr: sys.SockaddrIn = .{ .port = 0, .addr = @byteSwap(@as(u32, 0x7f000001)) };
    var len: u32 = @sizeOf(sys.SockaddrIn);
    try testing.expectEqual(0, sys.bind(peer, &addr, len));
    try testing.expectEqual(0, sys.getsockname(peer, &addr, &len));

    const socket = try UdpSocket.init(socketAddress);
    defer socket.deinit();

    var data = "hi".*;
    try socket.send(&.{
        .data = &data,
        .len = data.len,
        .peer = .{ .addr = 0x7f000001, .port = @byteSwap(addr.port) },
    });

    var buf: [16]u8 = undefined;
    try testing.expectEqual(2, sys.recv(peer, &buf, buf.len, 0));
    try testing.expectEqualStrings("hi", buf[0..2]);
}

test "nonblocking after init" {
    const socket = try UdpSocket.init(socketAddress);
    defer socket.deinit();

    const flags = sys.fcntl(socket.socket, sys.F.GETFL);
    try testing.expect(flags & sys.O.NONBLOCK != 0);
}
