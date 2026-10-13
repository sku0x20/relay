//! Darwin libc bindings.

pub extern "c" fn kqueue() c_int;
pub extern "c" fn close(fd: c_int) c_int;
pub extern "c" fn send(fd: c_int, buf: [*]const u8, len: usize, flags: c_int) isize;
pub extern "c" fn sendto(fd: c_int, buf: [*]const u8, len: usize, flags: c_int, addr: *const anyopaque, addr_len: u32) isize;
pub extern "c" fn recv(fd: c_int, buf: [*]u8, len: usize, flags: c_int) isize;
pub extern "c" fn socketpair(domain: c_int, kind: c_int, protocol: c_int, fds: *[2]c_int) c_int;
pub extern "c" fn socket(domain: c_int, kind: c_int, protocol: c_int) c_int;
pub extern "c" fn bind(fd: c_int, addr: *const anyopaque, len: u32) c_int;
pub extern "c" fn listen(fd: c_int, backlog: c_int) c_int;
pub extern "c" fn accept(fd: c_int, addr: ?*anyopaque, len: ?*u32) c_int;
pub extern "c" fn connect(fd: c_int, addr: *const anyopaque, len: u32) c_int;
pub extern "c" fn setsockopt(fd: c_int, level: c_int, name: c_int, value: *const anyopaque, len: u32) c_int;
pub extern "c" fn getsockname(fd: c_int, addr: *anyopaque, len: *u32) c_int;
pub extern "c" fn shutdown(fd: c_int, how: c_int) c_int;
pub extern "c" fn fcntl(fd: c_int, cmd: c_int, ...) c_int;
pub extern "c" fn signal(sig: c_int, handler: ?SIG.Handler) ?SIG.Handler;
pub extern "c" fn kevent(
    kq: c_int,
    changelist: ?[*]const Kevent,
    nchanges: c_int,
    eventlist: ?[*]Kevent,
    nevents: c_int,
    timeout: ?*const Timespec,
) c_int;

// --- fcntl ---

pub const F = struct {
    pub const GETFL: c_int = 3; // F_GETFL
    pub const SETFL: c_int = 4; // F_SETFL
};

pub const O = struct {
    pub const NONBLOCK: c_int = 0x0004; // O_NONBLOCK
};

// --- Sockets ---

pub const AF = struct {
    pub const UNIX: c_int = 1; // AF_UNIX
    pub const INET: c_int = 2; // AF_INET
};

pub const SOL = struct {
    pub const SOCKET: c_int = 0xffff; // SOL_SOCKET
};

pub const SO = struct {
    pub const REUSEADDR: c_int = 0x0004; // SO_REUSEADDR
};

pub const INADDR = struct {
    pub const LOOPBACK: u32 = 0x7f000001; // INADDR_LOOPBACK
};

/// IPv4 address; `port` and `addr` are in network byte order.
pub const SockaddrIn = extern struct {
    len: u8 = @sizeOf(SockaddrIn),
    family: u8 = AF.INET,
    port: u16,
    addr: u32,
    zero: [8]u8 = @splat(0),
};

pub const SOCK = struct {
    pub const STREAM: c_int = 1; // SOCK_STREAM
    pub const DGRAM: c_int = 2; // SOCK_DGRAM
};

/// Largest `listen` backlog: the kernel clamps a negative backlog to `kern.ipc.somaxconn`.
pub const BACKLOG_MAX: c_int = -1;

pub const MSG = struct {
    pub const NOSIGNAL: c_int = 0x80000; // MSG_NOSIGNAL
};

pub const SHUT = struct {
    pub const WR: c_int = 1; // SHUT_WR
};

// --- kevent ---

pub const Kevent = extern struct {
    ident: usize,
    filter: i16,
    flags: u16,
    fflags: u32,
    data: isize,
    udata: ?*anyopaque,
};

pub const Timespec = extern struct {
    sec: c_long,
    nsec: c_long,
};

pub const EV = struct {
    pub const ADD: u16 = 0x0001; // EV_ADD
    pub const DELETE: u16 = 0x0002; // EV_DELETE
    pub const ENABLE: u16 = 0x0004; // EV_ENABLE
    pub const DISABLE: u16 = 0x0008; // EV_DISABLE
    pub const CLEAR: u16 = 0x0020; // EV_CLEAR
    pub const ERROR: u16 = 0x4000; // EV_ERROR
    pub const EOF: u16 = 0x8000; // EV_EOF
};

// --- Filters ---

pub const READ = struct {
    pub const FILTER: i16 = -1; // EVFILT_READ
};

pub const WRITE = struct {
    pub const FILTER: i16 = -2; // EVFILT_WRITE
};

pub const USER = struct {
    pub const FILTER: i16 = -10; // EVFILT_USER
    pub const TRIGGER: u32 = 0x01000000; // NOTE_TRIGGER
};

// --- Signals ---

pub const SIG = struct {
    pub const Handler = *const fn (c_int) callconv(.c) void;
    pub const DFL: ?Handler = null; // SIG_DFL
    pub const PIPE: c_int = 13; // SIGPIPE
};

// --- Errors ---

extern "c" fn __error() *c_int;

pub const E = enum(c_int) {
    SUCCESS = 0,
    NOENT = 2,
    BADF = 9,
    PIPE = 32,
    AGAIN = 35,
    ADDRINUSE = 48,
    _,
};

/// Errno of the last call if `rc` is -1, else `.SUCCESS`.
pub fn errno(rc: anytype) E {
    return if (rc == -1) @enumFromInt(__error().*) else .SUCCESS;
}
