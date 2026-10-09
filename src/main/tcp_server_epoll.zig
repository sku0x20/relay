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

    var eventList: [1]linux.epoll_event = undefined;
    while (true) {
        const events = posix.epoll_wait(epoll, &eventList, -1);
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
    event: linux.epoll_event,
    client_fd: posix.socket_t,
) void {
    // in case of any error close the fd;
    // so its removed from epoll event listener
    processEvent(event, client_fd) catch |err| {
        // todo: handle errs explicitly
        std.log.err("{s}", .{@errorName(err)});
        posix.close(client_fd);
    };
}

fn processEvent(
    event: linux.epoll_event,
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

// todo: in case of accept failure close this socket; and reinitiate the socket;
fn acceptConn(
    epoll: i32,
    event: linux.epoll_event,
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
    try addConnectionToEpoll(epoll, client_socket_fd);
}

fn addConnectionToEpoll(epoll: i32, conn: posix.socket_t) !void {
    std.debug.assert(conn >= 0);
    var event = linux.epoll_event{
        .events = linux.EPOLL.IN,
        .data = .{ .fd = conn },
    };
    try posix.epoll_ctl(epoll, linux.EPOLL.CTL_ADD, conn, &event);
}


fn addListenerToEpoll(epoll: i32, socket: posix.socket_t) !void {
    std.debug.assert(socket >= 0);
    var event = linux.epoll_event{
        .events = linux.EPOLL.IN,
        .data = .{ .fd = socket },
    };
    try posix.epoll_ctl(epoll, linux.EPOLL.CTL_ADD, socket, &event);
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
