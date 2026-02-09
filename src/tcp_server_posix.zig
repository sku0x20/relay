const std = @import("std");
const posix = std.posix;
const Thread = std.Thread;
const errUtils = @import("err_utils.zig");

// todo: use CLOEXEC flag wherever applicable

pub fn start(
    bind: []const u8,
    port: u16,
) !void {
    const kq = try posix.kqueue();

    const socket = try createSocket();
    const addr = try std.net.Ip4Address.resolveIp(bind, port);
    try bindSocket(socket, addr);
    try listen(socket);
    defer posix.close(socket);

    std.debug.assert(socket >= 0);
    const event = posix.Kevent{
        .ident = @as(usize, @intCast(socket)),
        .filter = std.c.EVFILT.READ,
        .flags = std.c.EV.ADD,
        .fflags = 0,
        .data = 0,
        .udata = 0,
    };
    const changeList = &[_]posix.Kevent{event};
    const n = try posix.kevent(kq, changeList, &.{}, null);
    std.debug.assert(n == 0);

    while (true) {
        var eventList: [1]posix.Kevent = undefined;
        const events = try posix.kevent(kq, &.{}, &eventList, null);
        std.log.info("event = {}", .{events});
        std.log.info("event list = {any}", .{eventList});
    }

    //
    // while (true) {
    //     var accepted_addr: std.net.Ip4Address = undefined;
    //     const client_socket_fd = try posix.accept(
    //         socket,
    //         @ptrCast(&accepted_addr.sa),
    //         @constCast(&accepted_addr.getOsSockLen()),
    //         posix.SOCK.NONBLOCK,
    //     );
    //
    //     try pool.spawn(errUtils.runCatching, .{ handleConnection, .{ client_socket_fd, accepted_addr } });
    // }
}

fn handleConnection(
    client_fd: posix.socket_t,
    accepted_addr: std.net.Ip4Address,
) !void {
    defer posix.close(client_fd);

    _ = accepted_addr;

    while (true) {
        var buf: [4]u8 = undefined;
        const n = posix.read(client_fd, &buf) catch |err| switch (err) {
            error.ConnectionResetByPeer => return,
            // add other errors;
            // std/posix.zig:856
            else => return err,
        };
        std.log.info("read = {}", .{n});

        // eof
        if (n == 0) {
            return;
        }

        const chunk = buf[0..n];
        _ = chunk;

        const data = "pong";
        const w = try posix.write(client_fd, data);
        std.log.info("wrote = {}", .{w});
    }
}

fn createSocket() !posix.socket_t {
    // ipv4 tcp socket
    const socket_fd = try posix.socket(
        posix.AF.INET,
        // is NONBLOCKING really required? Kqueue can work without this flag also
        // what it will do is accept will return error.
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
