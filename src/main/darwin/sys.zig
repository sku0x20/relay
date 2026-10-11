//! Darwin libc bindings.

pub extern "c" fn kqueue() c_int;
pub extern "c" fn close(fd: c_int) c_int;
pub extern "c" fn send(fd: c_int, buf: [*]const u8, len: usize, flags: c_int) isize;
pub extern "c" fn recv(fd: c_int, buf: [*]u8, len: usize, flags: c_int) isize;
pub extern "c" fn socketpair(domain: c_int, kind: c_int, protocol: c_int, fds: *[2]c_int) c_int;
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
};

pub const SOCK = struct {
    pub const STREAM: c_int = 1; // SOCK_STREAM
};

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
    pub const ENABLE: u16 = 0x0004; // EV_ENABLE
    pub const DISABLE: u16 = 0x0008; // EV_DISABLE
    pub const CLEAR: u16 = 0x0020; // EV_CLEAR
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
    BADF = 9,
    PIPE = 32,
    AGAIN = 35,
    _,
};

/// Errno of the last call if `rc` is -1, else `.SUCCESS`.
pub fn errno(rc: anytype) E {
    return if (rc == -1) @enumFromInt(__error().*) else .SUCCESS;
}
