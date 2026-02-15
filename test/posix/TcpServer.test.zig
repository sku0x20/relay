const std = @import("std");
const TcpServer = @import("src/posix/TcpServer.zig");

test "passing" {
    try std.testing.expect(1 == 1);
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