const std = @import("std");
const process_utils = @import("process_utils.zig");
const tcp_utils = @import("tcp_utils.zig");

test "e2e" {
    const exe_path = try std.process.getEnvVarOwned(std.testing.allocator, "RELAY_BIN");
    defer std.testing.allocator.free(exe_path);

    var child = try process_utils.spawnRelay(std.testing.allocator, exe_path);
    defer process_utils.cleanup(&child);

    try tcp_utils.waitForPortOpen(
        std.testing.allocator,
        "127.0.0.1",
        19000,
        2 * std.time.ns_per_s,
    );

    try ping();
}

fn ping() !void {
    var stream = try std.net.tcpConnectToHost(std.testing.allocator, "127.0.0.1", 19000);
    defer stream.close();

    var stream_writer = stream.writer(&.{});
    var writer = &stream_writer.interface;
    try writer.writeAll("ping");

    var stream_reader = stream.reader(&.{});
    var buf: [4]u8 = undefined;
    try stream_reader.interface().readSliceAll(&buf);
    try std.testing.expect(std.mem.eql(u8, &buf, "pong"));
}
