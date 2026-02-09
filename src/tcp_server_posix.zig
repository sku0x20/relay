const std = @import("std");
const posix = std.posix;
const Thread = std.Thread;
const errUtils = @import("err_utils.zig");

pub fn start(
    bind: []const u8,
    port: u16,
    pool: *Thread.Pool,
) !void {
    const socket = try createSocket();
    const addr = try std.net.Ip4Address.resolveIp(bind, port);
    try bindSocket(socket, addr);
    try listen(socket);
    defer posix.close(socket);

    while (true) {
        var accepted_addr: std.net.Ip4Address = undefined;
        const client_socket_fd = try posix.accept(
            socket,
            @ptrCast(&accepted_addr.sa),
            @constCast(&accepted_addr.getOsSockLen()),
            0,
        );

        try pool.spawn(errUtils.runCatching, .{ handleConnection, .{ client_socket_fd, accepted_addr } });
    }
}

fn handleConnection(
    client_fd: posix.socket_t,
    accepted_addr: std.net.Ip4Address,
) !void {
    defer posix.close(client_fd);

    _ = accepted_addr;

    var buf: [4]u8 = undefined;

    // todo: end of stream handling and other error handing
    const n = try posix.read(client_fd, &buf);
    std.log.info("read = {}", .{n});

    const data = "pong";
    const w = try posix.write(client_fd, data);
    std.log.info("wrote = {}", .{w});
}

fn createSocket() !posix.socket_t {
    // ipv4 tcp socket
    const socket_fd = try posix.socket(
        posix.AF.INET,
        posix.SOCK.STREAM,
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

    // macOS: prevent SIGPIPE on write() to a closed peer
    // get error instead of process signal termination.
    try posix.setsockopt(
        socket_fd,
        posix.SOL.SOCKET,
        posix.SO.NOSIGPIPE,
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
