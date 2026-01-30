const std = @import("std");
const Server = std.net.Server;

pub fn startRelay() !void {
    const address = try std.net.Address.parseIp("127.0.0.1", 19000);
    var server = try std.net.Address.listen(address, .{
        .reuse_address = true,
    });
    defer server.deinit();

    while (true) {
        const connection = try server.accept();
        try handleConnection(&connection);
    }
}

pub fn handleConnection(connection: *const Server.Connection) !void {
    defer connection.stream.close();

    var reader = connection.stream.reader(&.{});
    var buf: [4]u8 = undefined;
    reader.interface().readSliceAll(&buf) catch |err| switch (err) {
        error.EndOfStream => return,
        else => return err,
    };
    if (!std.mem.eql(u8, &buf, "ping")) return;

    var stream_writer = connection.stream.writer(&.{});
    try stream_writer.interface.writeAll("pong");
}
