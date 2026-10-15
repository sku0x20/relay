const std = @import("std");
const sys = @import("sys.zig");

const UdpServer = @This();

sockAddrIn: sys.SockaddrIn,

/// `addr` is dotted IPv4, e.g. "127.0.0.1".
pub fn init(addr: []const u8, port: u16) std.Io.net.Ip4Address.ParseError!UdpServer {
    const ip4: std.Io.net.Ip4Address = try .parse(addr, port);
    return .{
        .sockAddrIn = .{
            .port = std.mem.nativeToBig(u16, ip4.port),
            // bytes are already in network order.
            .addr = @bitCast(ip4.bytes),
        },
    };
}
