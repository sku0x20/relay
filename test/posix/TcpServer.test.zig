const std = @import("std");
const TcpServer = @import("src/posix/TcpServer.zig");

test "passing" {
    try std.testing.expect(1 == 1);
}
