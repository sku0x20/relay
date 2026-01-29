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

    try waitForPortOpen(
        std.testing.allocator,
        "127.0.0.1",
        19000,
        2 * std.time.ms_per_s,
    );

    try ping();
}

fn ping() !void {
    var stream = try std.net.tcpConnectToHost(std.testing.allocator, "127.0.0.1", 19000);
    defer stream.close();

    const stream_writer = stream.writer(&.{});
    var writer = stream_writer.interface;
    try writer.writeAll("ping");

    var stream_reader = stream.reader(&.{});
    const reader = stream_reader.interface();
    var buf: [4]u8 = undefined;
    try reader.readSliceAll(&buf);
    try std.testing.expect(std.mem.eql(u8, &buf, "pong"));
}

fn waitForPortOpen(
    allocator: std.mem.Allocator,
    host: []const u8,
    port: u16,
    timeout_ms: u64,
) !void {
    const start = std.time.milliTimestamp();
    while ((std.time.milliTimestamp() - start) < timeout_ms) {
        if (std.net.tcpConnectToHost(allocator, host, port)) |stream| {
            stream.close();
            return;
        } else |err| switch (err) {
            error.ConnectionRefused => {},
            else => return err,
        }
        std.Thread.sleep(timeout_ms * std.time.ns_per_ms);
    }
    return error.ConnectionRefused;
}
