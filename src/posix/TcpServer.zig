const TcpServer = @This();

_bind: []const u8,
_port: u16,

pub fn init(
    bind: []const u8,
    port: u16,
) TcpServer {
    return .{
        ._bind = bind,
        ._port = port,
    };
}

pub fn start(self: *const TcpServer) !void {
    _ = self;
}
