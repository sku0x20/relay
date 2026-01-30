const std = @import("std");
const Thread = std.Thread;
const errUtils = @import("err_utils.zig");
const Server = std.net.Server;

pub fn start(
    bind: []const u8,
    port: u16,
    pool: *Thread.Pool,
) !void {
    const address = try std.net.Address.parseIp(bind, port);
    var server = try std.net.Address.listen(address, .{
        .reuse_address = true,
    });
    defer server.deinit();

    while (true) {
        const connection = try server.accept();
        try pool.spawn(errUtils.runCatching, .{ handleConnection, .{connection} });
    }
}

fn handleConnection(connection: Server.Connection) !void {
    defer connection.stream.close();

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
