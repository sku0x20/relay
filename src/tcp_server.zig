const std = @import("std");
const Thread = std.Thread;
const errUtils = @import("err_utils.zig");
const Server = std.net.Server;

pub fn start(
    bind: []const u8,
    port: u16,
    max_connections: usize,
    pool: *Thread.Pool,
) !void {
    const address = try std.net.Address.parseIp(bind, port);
    var server = try std.net.Address.listen(address, .{
        .reuse_address = true,
    });
    defer server.deinit();

    var active_connections = std.atomic.Value(usize).init(0);

    while (true) {
        const connection = try server.accept();
        const prev = active_connections.fetchAdd(1, .acq_rel);
        if (prev >= max_connections) {
            _ = active_connections.fetchSub(1, .acq_rel);
            connection.stream.close();
            continue;
        }
        try pool.spawn(errUtils.runCatching, .{ handleConnection, .{connection, &active_connections} });
    }
}

fn handleConnection(
    connection: Server.Connection,
    active_connections: *std.atomic.Value(usize),
) !void {
    defer {
        connection.stream.close();
        _ = active_connections.fetchSub(1, .acq_rel);
    }

    var reader = connection.stream.reader(&.{});
    var buf: [4]u8 = undefined;
    reader.interface().readSliceAll(&buf) catch |err| switch (err) {
        error.EndOfStream => return,
        else => return err,
    };
    if (!std.mem.eql(u8, &buf, "ping")) return;

    var stream_writer = connection.stream.writer(&.{});
    try stream_writer.interface.writeAll("pong");
}
