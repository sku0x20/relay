const std = @import("std");
const buildin = @import("builtin");
const sys = @import("sys.zig");
const Thread = std.Thread;
const errUtils = @import("err_utils.zig");

// todo: use CLOEXEC flag wherever applicable

pub fn start(
    bind: [:0]const u8,
    port: u16,
) !void {
    // todo: defer close kq
    const kq = try sys.kqueue();

    const socket = try createSocket();
    const addr = try sys.ip4(bind, port);
    try bindSocket(socket, &addr);
    try listen(socket);
    defer sys.close(socket);

    try addListenerToKq(kq, socket);

    // todo: use userdata as function callback;
    // todo: optimizations; use the backlog returned in .data for accept connections in loop???
    // { .{ .ident = 4, .filter = -1, .flags = 1, .fflags = 0, .data = 1, .udata = 0 } }

    const listener_ident = @as(usize, @intCast(socket));
    var eventList: [1]sys.Kevent = undefined;
    while (true) {
        const events = try sys.kevent(kq, &.{}, &eventList, null);
        const event: sys.Kevent = eventList[0];
        _ = events;
        // std.log.debug("events = {}, event list = {any}", .{ events, eventList });
        // for now going with branching
        if (event.ident == listener_ident) {
            try acceptConn(kq, event, socket);
        } else {
            const client_socket_fd = @as(sys.fd_t, @intCast(event.ident));
            handleClientEvent(event, client_socket_fd);
        }
    }
}

// todo: in case of accept failure close this socket; and reinitiate the socket;
fn acceptConn(
    kq: i32,
    event: sys.Kevent,
    socket: sys.fd_t,
) !void {
    _ = event;
    const client_socket_fd = try sys.accept(socket, sys.SOCK.NONBLOCK);
    try addConnectionToKq(kq, client_socket_fd);
}

fn addListenerToKq(kq: i32, socket: sys.fd_t) !void {
    std.debug.assert(socket >= 0);
    const listener_ident = @as(usize, @intCast(socket));
    const listener_event = sys.Kevent{
        .ident = listener_ident,
        .filter = sys.EVFILT.READ,
        .flags = sys.EV.ADD,
        .fflags = 0,
        .data = 0,
        .udata = 0,
    };
    const changeList = &[_]sys.Kevent{listener_event};
    const n = try sys.kevent(kq, changeList, &.{}, null);
    std.debug.assert(n == 0);
}

fn addConnectionToKq(kq: i32, conn: sys.fd_t) !void {
    std.debug.assert(conn >= 0);
    const conn_ident = @as(usize, @intCast(conn));
    const conn_event = sys.Kevent{
        .ident = conn_ident,
        .filter = sys.EVFILT.READ,
        .flags = sys.EV.ADD,
        .fflags = 0,
        .data = 0,
        .udata = 0,
    };
    const changeList = &[_]sys.Kevent{conn_event};
    const n = try sys.kevent(kq, changeList, &.{}, null);
    std.debug.assert(n == 0);
}

fn handleClientEvent(
    event: sys.Kevent,
    client_fd: sys.fd_t,
) void {
    // in case of any error close the fd;
    // so its removed from kqueue event listener
    processEvent(event, client_fd) catch |err| {
        // todo: handle errs explicitly
        std.log.err("{s}", .{@errorName(err)});
        sys.close(client_fd);
    };
}

fn processEvent(
    event: sys.Kevent,
    client_fd: sys.fd_t,
) !void {
    _ = event;
    var buf: [4]u8 = undefined;
    const n = try sys.read(client_fd, &buf);

    // eof
    if (n == 0) {
        sys.close(client_fd);
        return;
    }

    const chunk = buf[0..n];
    _ = chunk;

    const data = "pong";
    const w = try sys.write(client_fd, data);
    _ = w;
}

fn createSocket() !sys.fd_t {
    // ipv4 tcp socket
    const socket_fd = try sys.socket(
        sys.AF.INET,
        // is NONBLOCKING really required? Kqueue can work without this flag also
        // accept also no error??? idk!
        sys.SOCK.STREAM | sys.SOCK.NONBLOCK,
        sys.IPPROTO.TCP,
    );
    errdefer sys.close(socket_fd);

    // socket options
    try sys.setsockoptInt(socket_fd, sys.SOL.SOCKET, sys.SO.REUSEADDR, 1);

    if (buildin.os.tag == .macos) {
        // macOS: prevent SIGPIPE on write() to a closed peer
        // get error instead of process signal termination.
        try sys.setsockoptInt(socket_fd, sys.SOL.SOCKET, sys.SO.NOSIGPIPE, 1);
    }

    // tcp options
    try sys.setsockoptInt(socket_fd, sys.IPPROTO.TCP, sys.TCP.NODELAY, 1);

    return socket_fd;
}

fn bindSocket(socket_fd: sys.fd_t, addr: *const sys.sockaddr_in) !void {
    try sys.bind(socket_fd, addr);
}

fn listen(socket_fd: sys.fd_t) !void {
    try sys.listen(socket_fd, 10);
}
