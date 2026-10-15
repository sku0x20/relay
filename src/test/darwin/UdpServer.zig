const UdpServer = @import("../../main/darwin/UdpServer.zig");

test "open and close" {
    const server = try UdpServer.init();
    try server.close();
}

test "open with deferred deinit" {
    const server = try UdpServer.init();
    defer server.deinit();
}
