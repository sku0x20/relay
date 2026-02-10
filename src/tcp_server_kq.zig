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

    try addListenerToKq(kq, socket);

    // todo: use userdata as function callback;
    // todo: optimizations; use the backlog returned in .data for accept connections in loop???
    // { .{ .ident = 4, .filter = -1, .flags = 1, .fflags = 0, .data = 1, .udata = 0 } }

    const listener_ident = @as(usize, @intCast(socket));
    var eventList: [1]posix.Kevent = undefined;
    while (true) {
        const events = try posix.kevent(kq, &.{}, &eventList, null);
        const event: posix.Kevent = eventList[0];
        _ = events;
        // std.log.debug("events = {}, event list = {any}", .{ events, eventList });
        // for now going with branching
        if (event.ident == listener_ident) {
            try acceptConn(kq, event, socket);
        } else {
            const client_socket_fd = @as(posix.socket_t, @intCast(event.ident));
            handleClientEvent(event, client_socket_fd);
        }
    }
}

// todo: in case of accept failure close this socket; and reinitiate the socket;
fn acceptConn(
    kq: i32,
    event: posix.Kevent,
    socket: posix.socket_t,
) !void {
    _ = event;
    var accepted_addr: std.net.Ip4Address = undefined;

    const client_socket_fd = try posix.accept(
        socket,
        @ptrCast(&accepted_addr.sa),
        @constCast(&accepted_addr.getOsSockLen()),
        posix.SOCK.NONBLOCK,
    );
    try addConnectionToKq(kq, client_socket_fd);
}

fn addListenerToKq(kq: i32, socket: posix.socket_t) !void {
    std.debug.assert(socket >= 0);
    const listener_ident = @as(usize, @intCast(socket));
    const listener_event = posix.Kevent{
        .ident = listener_ident,
        .filter = std.c.EVFILT.READ,
        .flags = std.c.EV.ADD,
        .fflags = 0,
        .data = 0,
        .udata = 0,
    };
    const changeList = &[_]posix.Kevent{listener_event};
    const n = try posix.kevent(kq, changeList, &.{}, null);
    std.debug.assert(n == 0);
}

fn addConnectionToKq(kq: i32, conn: posix.socket_t) !void {
    std.debug.assert(conn >= 0);
    const conn_ident = @as(usize, @intCast(conn));
    const conn_event = posix.Kevent{
        .ident = conn_ident,
        .filter = std.c.EVFILT.READ,
        .flags = std.c.EV.ADD,
        .fflags = 0,
        .data = 0,
        .udata = 0,
    };
    const changeList = &[_]posix.Kevent{conn_event};
    const n = try posix.kevent(kq, changeList, &.{}, null);
    std.debug.assert(n == 0);
}

fn handleClientEvent(
    event: posix.Kevent,
    client_fd: posix.socket_t,
) void {
    // in case of any error close the fd;
    // so its removed from kqueue event listener
    processEvent(event, client_fd) catch |err| {
        // todo: handle errs explicitly
        std.log.err("{s}", .{@errorName(err)});
        posix.close(client_fd);
    };
}

fn processEvent(
    event: posix.Kevent,
    client_fd: posix.socket_t,
) !void {
    _ = event;
    var buf: [4]u8 = undefined;
    const n = try posix.read(client_fd, &buf);

    // eof
    if (n == 0) {
        posix.close(client_fd);
        return;
    }

    const chunk = buf[0..n];
    _ = chunk;

    const data = "pong";
    const w = try posix.write(client_fd, data);
    _ = w;
}

fn createSocket() !posix.socket_t {
    // ipv4 tcp socket
    const socket_fd = try posix.socket(
        posix.AF.INET,
        // is NONBLOCKING really required? Kqueue can work without this flag also
        // accept also no error??? idk!
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
