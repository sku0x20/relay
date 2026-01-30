const std = @import("std");
const Thread = std.Thread;
const tcpServer = @import("tcp_server.zig");

pub fn startRelay() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit(); // todo: check for leaks!

    const allocator = gpa.allocator();

    const concurrency = 1024;

    var pool: Thread.Pool = undefined;
    try pool.init(.{
        .allocator = allocator,
        .n_jobs = concurrency,
    });
    defer pool.deinit();

    const bind = "127.0.0.1";
    const port = 19000;
    const max_connections = concurrency;
    try tcpServer.start(bind, port, max_connections, &pool);
}
