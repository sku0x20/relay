const std = @import("std");
const sys = @import("../../main/darwin/sys.zig");

test "kqueue opens and closes" {
    const fd = sys.kqueue();
    try std.testing.expect(fd >= 0);
    try std.testing.expectEqual(0, sys.close(fd));
}

test "EBADF closing invalid fd" {
    const rc = sys.close(-1);
    try std.testing.expectEqual(-1, rc);
    try std.testing.expectEqual(sys.E.BADF, sys.errno(rc));
}

// User filter: an event no kernel source fires; our own code triggers it.
test "user event delivered after trigger" {
    const kq = sys.kqueue();
    defer _ = sys.close(kq);

    const add = [_]sys.Kevent{.{
        .ident = 7,
        .filter = sys.USER.FILTER,
        .flags = sys.EV.ADD,
        .fflags = 0,
        .data = 0,
        .udata = null,
    }};
    // register event listening for User Events.
    const added = sys.kevent(kq, &add, add.len, null, 0, null);
    try std.testing.expectEqual(0, added);

    const trigger = [_]sys.Kevent{.{
        .ident = 7,
        .filter = sys.USER.FILTER,
        .flags = 0,
        .fflags = sys.USER.TRIGGER,
        .data = 0,
        .udata = null,
    }};
    // null will block indefinitely
    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    // trigger User Event and then collect it in events.
    const ready = sys.kevent(kq, &trigger, trigger.len, &events, events.len, &now);
    try std.testing.expectEqual(1, ready);

    try std.testing.expectEqual(7, events[0].ident);
    try std.testing.expectEqual(sys.USER.FILTER, events[0].filter);
}

test "udata returned with event" {
    const kq = sys.kqueue();
    defer _ = sys.close(kq);

    // stands in for the connection an event belongs to.
    var conn: u32 = 42;

    const add = [_]sys.Kevent{.{
        .ident = 7,
        .filter = sys.USER.FILTER,
        .flags = sys.EV.ADD,
        .fflags = sys.USER.TRIGGER,
        .data = 0,
        .udata = &conn,
    }};
    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    // register and trigger in one change; the kernel stores udata, never reading it.
    try std.testing.expectEqual(1, sys.kevent(kq, &add, add.len, &events, events.len, &now));

    // the event leads straight back to its owner, no lookup by fd.
    const owner: *u32 = @ptrCast(@alignCast(events[0].udata.?));
    try std.testing.expectEqual(&conn, owner);
    try std.testing.expectEqual(42, owner.*);
}

test "udata replaced by later change" {
    const kq = sys.kqueue();
    defer _ = sys.close(kq);

    var conn: u32 = 42;

    const add = [_]sys.Kevent{.{
        .ident = 7,
        .filter = sys.USER.FILTER,
        .flags = sys.EV.ADD,
        .fflags = 0,
        .data = 0,
        .udata = &conn,
    }};
    try std.testing.expectEqual(0, sys.kevent(kq, &add, add.len, null, 0, null));

    const trigger = [_]sys.Kevent{.{
        .ident = 7,
        .filter = sys.USER.FILTER,
        .flags = 0,
        .fflags = sys.USER.TRIGGER,
        .data = 0,
        .udata = null,
    }};
    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    try std.testing.expectEqual(1, sys.kevent(kq, &trigger, trigger.len, &events, events.len, &now));

    // any change overwrites udata, EV_ENABLE and EV_DISABLE included:
    // pass it on every change, not just the first.
    try std.testing.expectEqual(null, events[0].udata);
}

test "failed change reported as error event" {
    const kq = sys.kqueue();
    defer _ = sys.close(kq);

    const changes = [_]sys.Kevent{
        .{
            .ident = 1,
            .filter = sys.USER.FILTER,
            .flags = sys.EV.DELETE,
            .fflags = 0,
            .data = 0,
            .udata = null,
        },
        .{
            .ident = 2,
            .filter = sys.USER.FILTER,
            .flags = sys.EV.ADD,
            .fflags = 0,
            .data = 0,
            .udata = null,
        },
    };
    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [2]sys.Kevent = undefined;
    // delete something never added, then add something new.
    // with room in events, a failed change becomes an event, not a -1 return.
    try std.testing.expectEqual(1, sys.kevent(kq, &changes, changes.len, &events, events.len, &now));
    try std.testing.expectEqual(1, events[0].ident);
    try std.testing.expect(events[0].flags & sys.EV.ERROR != 0);
    // data holds the errno.
    try std.testing.expectEqual(@intFromEnum(sys.E.NOENT), events[0].data);

    const trigger = [_]sys.Kevent{.{
        .ident = 2,
        .filter = sys.USER.FILTER,
        .flags = 0,
        .fflags = sys.USER.TRIGGER,
        .data = 0,
        .udata = null,
    }};
    // the rest of the batch still applied.
    try std.testing.expectEqual(1, sys.kevent(kq, &trigger, trigger.len, &events, events.len, &now));
    try std.testing.expectEqual(2, events[0].ident);
}

test "ENOENT when no room for error event" {
    const kq = sys.kqueue();
    defer _ = sys.close(kq);

    const delete = [_]sys.Kevent{.{
        .ident = 1,
        .filter = sys.USER.FILTER,
        .flags = sys.EV.DELETE,
        .fflags = 0,
        .data = 0,
        .udata = null,
    }};
    // no events array: the failure falls back to -1 and errno.
    const rc = sys.kevent(kq, &delete, delete.len, null, 0, null);
    try std.testing.expectEqual(-1, rc);
    try std.testing.expectEqual(sys.E.NOENT, sys.errno(rc));
}
