const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

// todo: use CLOEXEC flag wherever applicable

pub fn start(
    bind: []const u8,
    port: u16,
) !void {
    const epoll = try posix.epoll_create1(0);
    defer posix.close(epoll);

    const socket = try createSocket();
    const addr = try std.net.Ip4Address.resolveIp(bind, port);
    try bindSocket(socket, addr);
    try listen(socket);
    defer posix.close(socket);

    try addListenerToEpoll(epoll, socket);
}

fn addListenerToEpoll(epoll: i32, socket: posix.socket_t) !void {
    std.debug.assert(socket >= 0);
    const event = &linux.epoll_event{
        .events = linux.EPOLL.IN,
        .data = .{ .fd = socket },
    };
    try posix.epoll_ctl(epoll, linux.EPOLL.CTL_ADD, socket, @constCast(event));
}

fn createSocket() !posix.socket_t {
    // ipv4 tcp socket
    const socket_fd = try posix.socket(
        posix.AF.INET,
        posix.SOCK.STREAM | posix.SOCK.NONBLOCK,
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

fn bindSocket(socket_fd: posix.socket_t, addr: std.net.Ip4Address) !void {
    try posix.bind(
        socket_fd,
        // since in is more specific in a way implementation; this works
        @ptrCast(&(addr.sa)),
        addr.getOsSockLen(),
    );
}

fn listen(socket_fd: posix.socket_t) !void {
    try posix.listen(socket_fd, 10);
}
