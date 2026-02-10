const std = @import("std");
const tcpServerPosix = @import("tcp_server_posix.zig");

pub fn startRelay() !void {
    const bind = "127.0.0.1";
    const port = 19000;

    try tcpServerPosix.start(bind, port);
}
