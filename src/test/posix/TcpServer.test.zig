const std = @import("std");
const sys = @import("../../main/sys.zig");
const TcpServer = @import("../../main/posix/TcpServer.zig");

test "passing" {
    try std.testing.expect(1 == 1);
}

test "acceptConnections" {
    var server = TcpServer.init("127.0.0.1", 0);
    try server.start();
    const port = server.port();
    std.debug.print("{}", .{port});
    const client = try sys.socket(sys.AF.INET, sys.SOCK.STREAM, sys.IPPROTO.TCP);
    defer sys.close(client);
    const addr = try sys.ip4("127.0.0.1", port);
    try sys.connect(client, &addr);
    std.debug.print("{}", .{client});
}

// create the server
// startListening
// get port
// create client
// client init connection
// write from client
// read from the server; assert it
// write to the server;
// read from client; assert it
// close the client
// stop the server
