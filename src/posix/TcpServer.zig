const std = @import("std");
const buildin = @import("buildin");
const posix = std.posix;

const TcpServer = @This();

_bind: []const u8,
_port: u16,
_socket: posix.socket_t = undefined,

pub fn init(
    bind: []const u8,
    p: u16,
) TcpServer {
    return .{
        ._bind = bind,
        ._port = p,
    };
}

pub fn start(self: *const TcpServer) !void {
    self._socket = try createSocket();
}

pub fn port(self: *const TcpServer) u16 {
    return self._port;
}

fn createSocket() !posix.socket_t {
    // ipv4 tcp socket
    const socket_fd = try posix.socket(
        posix.AF.INET,
        posix.SOCK.STREAM | posix.SOCK.NONBLOCK | posix.SOCK.CLOEXEC,
        posix.IPPROTO.TCP,
    );
    errdefer posix.close(socket_fd);

    // socket options
    try posix.setsockopt(
        socket_fd,
        posix.SOL.SOCKET,
        posix.SO.REUSEADDR,
        // the f8ck is this api!!
        &std.mem.toBytes(@as(c_int, 1)),
    );

    // tcp options
    try posix.setsockopt(
        socket_fd,
        posix.IPPROTO.TCP,
        posix.TCP.NODELAY,
        &std.mem.toBytes(@as(c_int, 1)),
    );

    return socket_fd;
}
