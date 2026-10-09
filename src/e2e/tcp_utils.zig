const std = @import("std");
const c = std.c;
const sys = @import("../main/sys.zig");

pub fn connect(host: [:0]const u8, port: u16) !sys.fd_t {
    const fd = try sys.socket(sys.AF.INET, sys.SOCK.STREAM | sys.SOCK.CLOEXEC, sys.IPPROTO.TCP);
    errdefer sys.close(fd);
    const addr = try sys.ip4(host, port);
    try sys.connect(fd, &addr);
    return fd;
}

pub fn writeAll(fd: sys.fd_t, data: []const u8) !void {
    var i: usize = 0;
    while (i < data.len) i += try sys.write(fd, data[i..]);
}

pub fn readAll(fd: sys.fd_t, buf: []u8) !void {
    var i: usize = 0;
    while (i < buf.len) {
        const n = try sys.read(fd, buf[i..]);
        if (n == 0) return error.EndOfStream;
        i += n;
    }
}

pub fn waitForPortOpen(
    host: [:0]const u8,
    port: u16,
    timeout_ns: u64,
) !void {
    const start = monotonicNs();
    while (monotonicNs() - start < timeout_ns) {
        if (connect(host, port)) |fd| {
            sys.close(fd);
            return;
        } else |err| switch (err) {
            error.ConnectionRefused => {},
            else => return err,
        }
        sleepNs(20 * std.time.ns_per_ms);
    }
    return error.ConnectionRefused;
}

fn monotonicNs() u64 {
    var ts: c.timespec = undefined;
    std.debug.assert(c.clock_gettime(c.CLOCK.MONOTONIC, &ts) == 0);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}

fn sleepNs(ns: u64) void {
    var req: c.timespec = .{
        .sec = @intCast(ns / std.time.ns_per_s),
        .nsec = @intCast(ns % std.time.ns_per_s),
    };
    while (c.nanosleep(&req, &req) == -1) {}
}
