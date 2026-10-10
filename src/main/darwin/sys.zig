//! Darwin libc bindings.

pub extern "c" fn kqueue() c_int;
pub extern "c" fn close(fd: c_int) c_int;
