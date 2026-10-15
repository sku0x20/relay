const UdpSocket = @import("../../main/darwin/UdpSocket.zig");

test "open and close" {
    const socket = try UdpSocket.init();
    try socket.close();
}

test "open with deferred deinit" {
    const socket = try UdpSocket.init();
    defer socket.deinit();
}
