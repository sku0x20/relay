const std = @import("std");

pub fn waitForPortOpen(
    allocator: std.mem.Allocator,
    host: []const u8,
    port: u16,
    timeout_ns: u64,
) !void {
    const start = std.time.nanoTimestamp();
    while (std.time.nanoTimestamp() - start < timeout_ns) {
        if (std.net.tcpConnectToHost(allocator, host, port)) |stream| {
            stream.close();
            return;
        } else |err| switch (err) {
            error.ConnectionRefused => {},
            else => return err,
        }
        std.Thread.sleep(20 * std.time.ns_per_ms);
    }
    return error.ConnectionRefused;
}
