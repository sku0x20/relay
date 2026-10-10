//! Darwin libc bindings.

pub extern "c" fn kqueue() c_int;
pub extern "c" fn close(fd: c_int) c_int;
pub extern "c" fn kevent(
    kq: c_int,
    changelist: ?[*]const Kevent,
    nchanges: c_int,
    eventlist: ?[*]Kevent,
    nevents: c_int,
    timeout: ?*const Timespec,
) c_int;

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

pub const EVFILT = struct {
    pub const USER: i16 = -10;
};

pub const EV = struct {
    pub const ADD: u16 = 0x0001;
};

pub const NOTE = struct {
    pub const TRIGGER: u32 = 0x01000000;
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
