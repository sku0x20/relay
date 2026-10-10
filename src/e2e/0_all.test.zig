//! Lists every test file in src/e2e so they get compiled and run.

comptime {
    _ = @import("e2e.test.zig");
}
