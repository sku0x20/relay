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

    try pingMultiple();
}

fn pingMultiple() !void {
    var client1 = try std.net.tcpConnectToHost(std.testing.allocator, "127.0.0.1", 19000);
    defer client1.close();

    var c1_writer = client1.writer(&.{});
    try c1_writer.interface.writeAll("ping");

    var c1_reader = client1.reader(&.{});
    var c1_buf: [4]u8 = undefined;
    try c1_reader.interface().readSliceAll(&c1_buf);
    try std.testing.expect(std.mem.eql(u8, &c1_buf, "pong"));
}
