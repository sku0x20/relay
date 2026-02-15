const TcpServer = @This();

_bind: []const u8,
_port: u16,

pub fn startListening(
    bind: []const u8,
    port: u16,
) !TcpServer {
    _ = bind;
    _ = port;
}
