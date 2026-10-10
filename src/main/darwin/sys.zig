//! Darwin libc bindings.

pub extern "c" fn kqueue() c_int;
pub extern "c" fn close(fd: c_int) c_int;

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
