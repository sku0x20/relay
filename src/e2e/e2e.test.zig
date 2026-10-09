const std = @import("std");
const process_utils = @import("process_utils.zig");
const tcp_utils = @import("tcp_utils.zig");
const sys = @import("../main/sys.zig");

test "e2e" {
    const exe_path = std.mem.span(std.c.getenv("RELAY_BIN") orelse return error.RelayBinNotSet);

    const pid = try process_utils.spawnRelay(exe_path);
    defer process_utils.cleanup(pid);

    try tcp_utils.waitForPortOpen(
        "127.0.0.1",
        19000,
        2 * std.time.ns_per_s,
    );

    try pingMultiple();
}

fn pingMultiple() !void {
    const client1 = try tcp_utils.connect("127.0.0.1", 19000);
    defer sys.close(client1);

    const client2 = try tcp_utils.connect("127.0.0.1", 19000);
    defer sys.close(client2);

    const ping_count = 4;
    for (0..ping_count) |_| {
        try tcp_utils.writeAll(client1, "ping");
        try tcp_utils.writeAll(client2, "ping");

        var c1_buf: [4]u8 = undefined;
        try tcp_utils.readAll(client1, &c1_buf);
        try std.testing.expect(std.mem.eql(u8, &c1_buf, "pong"));

        var c2_buf: [4]u8 = undefined;
        try tcp_utils.readAll(client2, &c2_buf);
        try std.testing.expect(std.mem.eql(u8, &c2_buf, "pong"));
    }
}
