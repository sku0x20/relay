//! Thin wrappers over libc (`std.c`) that turn `-1` + errno into Zig errors.
//! Calls that can be interrupted by a signal are retried on EINTR.

const std = @import("std");
const builtin = @import("builtin");
const c = std.c;

pub const fd_t = c.fd_t;
pub const AF = c.AF;
pub const SOCK = c.SOCK;
pub const SOL = c.SOL;
pub const SO = c.SO;
pub const IPPROTO = c.IPPROTO;
pub const TCP = c.TCP;
pub const sockaddr_in = c.sockaddr.in;

pub const Error = error{
    WouldBlock,
    ConnectionRefused,
    ConnectionReset,
    BrokenPipe,
    AddressInUse,
    InvalidAddress,
    Unexpected,
};

// darwin has no SOCK_NONBLOCK / SOCK_CLOEXEC / accept4; std.c exposes shim
// bits for them which must be stripped and applied with fcntl instead.
const is_darwin = builtin.os.tag.isDarwin();
const shim_bits: u32 = if (is_darwin) SOCK.NONBLOCK | SOCK.CLOEXEC else 0;

fn check(rc: anytype) Error!@TypeOf(rc) {
    return switch (c.errno(rc)) {
        .SUCCESS => rc,
        .AGAIN => error.WouldBlock,
        .CONNREFUSED => error.ConnectionRefused,
        .CONNRESET => error.ConnectionReset,
        .PIPE => error.BrokenPipe,
        .ADDRINUSE => error.AddressInUse,
        else => |e| {
            std.log.err("unexpected errno: {any}", .{e});
            return error.Unexpected;
        },
    };
}

fn ReturnType(comptime func: anytype) type {
    return @typeInfo(@TypeOf(func)).@"fn".return_type.?;
}

fn checkRetry(comptime func: anytype, args: anytype) Error!ReturnType(func) {
    while (true) {
        const rc = @call(.auto, func, args);
        if (c.errno(rc) == .INTR) continue;
        return check(rc);
    }
}

fn applyShimFlags(fd: fd_t, flags: u32) Error!void {
    if (flags & SOCK.NONBLOCK != 0) {
        const nonblock: u32 = @bitCast(c.O{ .NONBLOCK = true });
        const fl = try check(c.fcntl(fd, @as(c_int, c.F.GETFL)));
        _ = try check(c.fcntl(fd, @as(c_int, c.F.SETFL), fl | @as(c_int, @bitCast(nonblock))));
    }
    if (flags & SOCK.CLOEXEC != 0) {
        _ = try check(c.fcntl(fd, @as(c_int, c.F.SETFD), @as(c_int, c.FD_CLOEXEC)));
    }
}

pub fn socket(domain: u32, sock_type: u32, protocol: u32) Error!fd_t {
    const fd = try check(c.socket(domain, sock_type & ~shim_bits, protocol));
    errdefer close(fd);
    if (is_darwin) try applyShimFlags(fd, sock_type);
    return fd;
}

pub fn setsockoptInt(fd: fd_t, level: i32, opt: u32, value: c_int) Error!void {
    _ = try check(c.setsockopt(fd, level, opt, &value, @sizeOf(c_int)));
}

extern "c" fn inet_pton(af: c_int, src: [*:0]const u8, dst: *anyopaque) c_int;

pub fn ip4(host: [:0]const u8, port: u16) Error!sockaddr_in {
    var addr: sockaddr_in = .{ .port = std.mem.nativeToBig(u16, port), .addr = 0 };
    return switch (inet_pton(AF.INET, host, &addr.addr)) {
        1 => addr,
        0 => error.InvalidAddress,
        else => |rc| {
            _ = try check(rc);
            unreachable;
        },
    };
}

pub fn bind(fd: fd_t, addr: *const sockaddr_in) Error!void {
    _ = try check(c.bind(fd, @ptrCast(addr), @sizeOf(sockaddr_in)));
}

pub fn listen(fd: fd_t, backlog: u32) Error!void {
    _ = try check(c.listen(fd, backlog));
}

pub fn connect(fd: fd_t, addr: *const sockaddr_in) Error!void {
    _ = try checkRetry(c.connect, .{ fd, @as(*const c.sockaddr, @ptrCast(addr)), @as(c.socklen_t, @sizeOf(sockaddr_in)) });
}

pub fn getsockname(fd: fd_t) Error!sockaddr_in {
    var addr: sockaddr_in = undefined;
    var len: c.socklen_t = @sizeOf(sockaddr_in);
    _ = try check(c.getsockname(fd, @ptrCast(&addr), &len));
    return addr;
}

/// `flags` takes SOCK.NONBLOCK / SOCK.CLOEXEC, like accept4.
pub fn accept(fd: fd_t, flags: u32) Error!fd_t {
    if (!is_darwin) return checkRetry(c.accept4, .{ fd, null, null, flags });
    const conn = try checkRetry(c.accept, .{ fd, null, null });
    errdefer close(conn);
    try applyShimFlags(conn, flags);
    return conn;
}

pub fn close(fd: fd_t) void {
    _ = c.close(fd);
}

pub fn read(fd: fd_t, buf: []u8) Error!usize {
    return @intCast(try checkRetry(c.read, .{ fd, buf.ptr, buf.len }));
}

pub fn write(fd: fd_t, buf: []const u8) Error!usize {
    return @intCast(try checkRetry(c.write, .{ fd, buf.ptr, buf.len }));
}

// kqueue (darwin, bsd)

pub const Kevent = c.Kevent;
pub const EVFILT = c.EVFILT;
pub const EV = c.EV;

pub fn kqueue() Error!fd_t {
    return check(c.kqueue());
}

pub fn kevent(kq: fd_t, changes: []const Kevent, events: []Kevent, timeout: ?*const c.timespec) Error!usize {
    return @intCast(try checkRetry(c.kevent, .{
        kq,
        changes.ptr,
        @as(c_int, @intCast(changes.len)),
        events.ptr,
        @as(c_int, @intCast(events.len)),
        timeout,
    }));
}

// epoll (linux)

pub const epoll_event = c.epoll_event;
pub const EPOLL = std.os.linux.EPOLL;

pub fn epoll_create1(flags: u32) Error!fd_t {
    return check(c.epoll_create1(flags));
}

pub fn epoll_ctl(epfd: fd_t, op: u32, fd: fd_t, event: ?*epoll_event) Error!void {
    _ = try check(c.epoll_ctl(epfd, op, fd, event));
}

pub fn epoll_wait(epfd: fd_t, events: []epoll_event, timeout: c_int) Error!usize {
    return @intCast(try checkRetry(c.epoll_wait, .{ epfd, events.ptr, @as(c_uint, @intCast(events.len)), timeout }));
}
