const std = @import("std");
const tcpServerKq = @import("tcp_server_kq.zig");

pub fn startRelay() !void {
    const bind = "127.0.0.1";
    const port = 19000;

    try tcpServerKq.start(bind, port);
}
