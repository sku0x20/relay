const std = @import("std");
const sys = @import("../sys.zig");

const TcpServer = @This();

_bind: [:0]const u8,
_port: u16,
_socket: sys.fd_t = undefined,

pub fn init(
    bind: [:0]const u8,
    p: u16,
) TcpServer {
    return .{
        ._bind = bind,
        ._port = p,
    };
}

pub fn start(self: *TcpServer) !void {
    self._socket = try createSocket();
}

pub fn port(self: *const TcpServer) u16 {
    return self._port;
}

fn createSocket() !sys.fd_t {
    // ipv4 tcp socket
    const socket_fd = try sys.socket(
        sys.AF.INET,
        sys.SOCK.STREAM | sys.SOCK.NONBLOCK | sys.SOCK.CLOEXEC,
        sys.IPPROTO.TCP,
    );
    errdefer sys.close(socket_fd);

    // socket options
    try sys.setsockoptInt(socket_fd, sys.SOL.SOCKET, sys.SO.REUSEADDR, 1);

    // tcp options
    try sys.setsockoptInt(socket_fd, sys.IPPROTO.TCP, sys.TCP.NODELAY, 1);

    return socket_fd;
}
