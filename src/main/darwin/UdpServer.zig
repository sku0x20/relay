const sys = @import("sys.zig");

const UdpServer = @This();

sockAddrIn: sys.SockaddrIn,

pub fn init(addr: []const u8, port: u16) error{InvalidAddress}!UdpServer {
    return .{
        .sockAddrIn = .{
            // darwin is little-endian; network order is big.
            .port = @byteSwap(port),
            // octets in memory order are already network order.
            .addr = @bitCast(try parseIp4(addr)),
        },
    };
}

/// Dotted IPv4, e.g. "127.0.0.1".
fn parseIp4(text: []const u8) error{InvalidAddress}![4]u8 {
    var octets: [4]u8 = undefined;
    var index: usize = 0;
    var value: u16 = 0;
    var digits: usize = 0;
    for (text) |c| switch (c) {
        '0'...'9' => {
            value = value * 10 + (c - '0');
            digits += 1;
            if (value > 255 or digits > 3) return error.InvalidAddress;
        },
        '.' => {
            if (digits == 0 or index == 3) return error.InvalidAddress;
            octets[index] = @intCast(value);
            index += 1;
            value = 0;
            digits = 0;
        },
        else => return error.InvalidAddress,
    };
    if (digits == 0 or index != 3) return error.InvalidAddress;
    octets[3] = @intCast(value);
    return octets;
}
