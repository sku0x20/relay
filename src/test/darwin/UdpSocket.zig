const testing = @import("std").testing;
const sys = @import("../../main/darwin/sys.zig");

const UdpSocket = @import("../../main/darwin/UdpSocket.zig");
const SocketAddress = @import("../../main/SocketAddress.zig");

const localhost: SocketAddress = .{
    .addr = 0x7f000001,
    .port = 0,
};

test "open and close" {
    const socket = try UdpSocket.init(localhost);
    try socket.close();
}

test "open with deferred deinit" {
    const socket = try UdpSocket.init(localhost);
    defer socket.deinit();
}

test "bound to requested port" {
    const socket = try UdpSocket.init(.{ .addr = localhost.addr, .port = 48879 });
    defer socket.deinit();

    try testing.expectEqual(@byteSwap(@as(u16, 48879)), socket.addr.port);
}

fn addressOf(socket: *const UdpSocket) SocketAddress {
    return .{ .addr = @byteSwap(socket.addr.addr), .port = @byteSwap(socket.addr.port) };
}

fn recvWait(socket: *const UdpSocket, datagram: *UdpSocket.Datagram) !void {
    for (0..100) |_| {
        if (socket.recv(datagram)) |_| return else |err| if (err != error.Again) return err;
        try testing.io.sleep(.fromMilliseconds(1), .awake);
    }
    return error.Timeout;
}

test "datagram delivered by send" {
    const sender = try UdpSocket.init(localhost);
    defer sender.deinit();
    const receiver = try UdpSocket.init(localhost);
    defer receiver.deinit();

    var payload = "hi".*;
    try sender.send(&.{ .data = &payload, .len = payload.len, .peer = addressOf(&receiver) });

    var buf: [16]u8 = undefined;
    var datagram: UdpSocket.Datagram = .{ .data = &buf, .len = 0, .peer = undefined };
    try recvWait(&receiver, &datagram);

    try testing.expectEqualStrings("hi", datagram.data[0..datagram.len]);
}

test "datagram received by recv" {
    const socket = try UdpSocket.init(localhost);
    defer socket.deinit();

    const peerFd = sys.socket(sys.AF.INET, sys.SOCK.DGRAM, 0);
    defer _ = sys.close(peerFd);
    try testing.expectEqual(2, sys.sendto(peerFd, "hi", 2, 0, &socket.addr, @sizeOf(sys.SockaddrIn)));

    var peerAddr: sys.SockaddrIn = undefined;
    var peerAddrLen: u32 = @sizeOf(sys.SockaddrIn);
    try testing.expectEqual(0, sys.getsockname(peerFd, &peerAddr, &peerAddrLen));

    var buf: [16]u8 = undefined;
    var datagram: UdpSocket.Datagram = .{ .data = &buf, .len = 0, .peer = undefined };
    for (0..100) |_| {
        if (socket.recv(&datagram)) |_| break else |err| if (err != error.Again) return err;
        try testing.io.sleep(.fromMilliseconds(1), .awake);
    } else return error.Timeout;

    try testing.expectEqualStrings("hi", datagram.data[0..datagram.len]);
    try testing.expectEqual(SocketAddress{ .addr = localhost.addr, .port = @byteSwap(peerAddr.port) }, datagram.peer);
}

test "nonblocking after init" {
    const socket = try UdpSocket.init(localhost);
    defer socket.deinit();

    const flags = sys.fcntl(socket.socket, sys.F.GETFL);
    try testing.expect(flags & sys.O.NONBLOCK != 0);
}
