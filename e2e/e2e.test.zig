const std = @import("std");

test "e2e" {
    const exe_path = try std.process.getEnvVarOwned(std.testing.allocator, "RELAY_BIN");
    defer std.testing.allocator.free(exe_path);

    var child = std.process.Child.init(&.{exe_path}, std.testing.allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    defer {
        _ = child.kill() catch |err| {
            std.debug.print("e2e: kill failed: {s}\n", .{@errorName(err)});
        };
        _ = child.wait() catch |err| {
            std.debug.print("e2e: wait failed: {s}\n", .{@errorName(err)});
        };
    }

    // todo: wait for port to be opened.

    try ping();
}

fn ping() !void {
    var stream = try std.net.tcpConnectToHost(std.testing.allocator, "127.0.0.1", 19000);
    defer stream.close();

    // var write_buf: [64]u8 = undefined;
    // var writer = stream.writer(&write_buf);
    // try writer.interface.writeAll("ping");

    var read_buf: [64]u8 = undefined;
    var stream_reader = stream.reader(&read_buf);
    const reader = stream_reader.interface();
    try reader.readSliceAll(&read_buf);
    try std.testing.expect(std.mem.eql(u8, &read_buf, "pong"));
}
