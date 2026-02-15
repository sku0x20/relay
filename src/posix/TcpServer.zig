const TcpServer = @This();

_bind: []const u8,
_port: u16,

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
    _ = self;
}

pub fn port(self: *const TcpServer) u16 {
    return self._port;
}
