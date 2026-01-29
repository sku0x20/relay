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

    var stream_reader = stream.reader(&.{});
    const reader = stream_reader.interface();
    var buf: [4]u8 = undefined;
    try reader.readSliceAll(&buf);
    try std.testing.expect(std.mem.eql(u8, &buf, "pong"));
}
