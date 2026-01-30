const std = @import("std");
const Thread = std.Thread;
const tcpServer = @import("tcp_server.zig");

pub fn startRelay() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit(); // todo: check for leaks!

    const allocator = gpa.allocator();

    var pool: Thread.Pool = undefined;
    try pool.init(.{
        .allocator = allocator,
        .n_jobs = 1,
    });
    defer pool.deinit();

    const bind = "127.0.0.1";
    const port = 19000;
    try tcpServer.start(bind, port, &pool);
}
