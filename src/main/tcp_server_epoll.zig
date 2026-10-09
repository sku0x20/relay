const std = @import("std");
const sys = @import("sys.zig");

// todo: use CLOEXEC flag wherever applicable

pub fn start(
    bind: [:0]const u8,
    port: u16,
) !void {
    const epoll = try sys.epoll_create1(0);
    defer sys.close(epoll);

    const socket = try createSocket();
    const addr = try sys.ip4(bind, port);
    try bindSocket(socket, &addr);
    try listen(socket);
    defer sys.close(socket);

    try addListenerToEpoll(epoll, socket);

    var eventList: [1]sys.epoll_event = undefined;
    while (true) {
        const events = try sys.epoll_wait(epoll, &eventList, -1);
        _ = events;
        const event = eventList[0];
        // std.log.debug("events = {}, event list = {any}", .{ events, eventList });
        // for now going with branching
        if(event.data.fd == socket){
            try acceptConn(epoll, event, socket);
        }else{
            const client_fd = event.data.fd;
            handleClientEvent(event, client_fd);
        }
    }
}

fn handleClientEvent(
    event: sys.epoll_event,
    client_fd: sys.fd_t,
) void {
    // in case of any error close the fd;
    // so its removed from epoll event listener
    processEvent(event, client_fd) catch |err| {
        // todo: handle errs explicitly
        std.log.err("{s}", .{@errorName(err)});
        sys.close(client_fd);
    };
}

fn processEvent(
    event: sys.epoll_event,
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

// todo: in case of accept failure close this socket; and reinitiate the socket;
fn acceptConn(
    epoll: i32,
    event: sys.epoll_event,
    socket: sys.fd_t,
) !void {
    _ = event;
    const client_socket_fd = try sys.accept(socket, sys.SOCK.NONBLOCK);
    try addConnectionToEpoll(epoll, client_socket_fd);
}

fn addConnectionToEpoll(epoll: i32, conn: sys.fd_t) !void {
    std.debug.assert(conn >= 0);
    var event = sys.epoll_event{
        .events = sys.EPOLL.IN,
        .data = .{ .fd = conn },
    };
    try sys.epoll_ctl(epoll, sys.EPOLL.CTL_ADD, conn, &event);
}


fn addListenerToEpoll(epoll: i32, socket: sys.fd_t) !void {
    std.debug.assert(socket >= 0);
    var event = sys.epoll_event{
        .events = sys.EPOLL.IN,
        .data = .{ .fd = socket },
    };
    try sys.epoll_ctl(epoll, sys.EPOLL.CTL_ADD, socket, &event);
}

fn createSocket() !sys.fd_t {
    // ipv4 tcp socket
    const socket_fd = try sys.socket(
        sys.AF.INET,
        sys.SOCK.STREAM | sys.SOCK.NONBLOCK,
        sys.IPPROTO.TCP,
    );
    errdefer sys.close(socket_fd);

    // socket options
    try sys.setsockoptInt(socket_fd, sys.SOL.SOCKET, sys.SO.REUSEADDR, 1);

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
