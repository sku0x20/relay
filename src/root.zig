const std = @import("std");
const Server = std.net.Server;
const Thread = std.Thread;
const errUtils = @import("err_utils.zig");

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

    const address = try std.net.Address.parseIp("127.0.0.1", 19000);
    var server = try std.net.Address.listen(address, .{
        .reuse_address = true,
    });
    defer server.deinit();

    while (true) {
        const connection = try server.accept();
        try pool.spawn(errUtils.runCatching, .{ handleConnection, .{connection} });
    }
}

pub fn handleConnection(connection: Server.Connection) !void {
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
