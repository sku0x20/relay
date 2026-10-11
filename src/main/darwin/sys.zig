//! Darwin libc bindings.

pub extern "c" fn kqueue() c_int;
pub extern "c" fn close(fd: c_int) c_int;
pub extern "c" fn read(fd: c_int, buf: [*]u8, nbyte: usize) isize;
pub extern "c" fn write(fd: c_int, buf: [*]const u8, nbyte: usize) isize;
pub extern "c" fn socketpair(domain: c_int, kind: c_int, protocol: c_int, fds: *[2]c_int) c_int;
pub extern "c" fn kevent(
    kq: c_int,
    changelist: ?[*]const Kevent,
    nchanges: c_int,
    eventlist: ?[*]Kevent,
    nevents: c_int,
    timeout: ?*const Timespec,
) c_int;

// --- Sockets ---

pub const AF = struct {
    pub const UNIX: c_int = 1; // AF_UNIX
};

pub const SOCK = struct {
    pub const STREAM: c_int = 1; // SOCK_STREAM
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
};

// --- Filters ---

pub const READ = struct {
    pub const FILTER: i16 = -1; // EVFILT_READ
};

pub const USER = struct {
    pub const FILTER: i16 = -10; // EVFILT_USER
    pub const TRIGGER: u32 = 0x01000000; // NOTE_TRIGGER
};

// --- Errors ---

extern "c" fn __error() *c_int;

pub const E = enum(c_int) {
    SUCCESS = 0,
    BADF = 9,
    _,
};

/// Errno of the last call if `rc` is -1, else `.SUCCESS`.
pub fn errno(rc: c_int) E {
    return if (rc == -1) @enumFromInt(__error().*) else .SUCCESS;
}
