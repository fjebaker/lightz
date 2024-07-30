const std = @import("std");
const lightz = @import("lightz");

const Context = struct {
    theme: lightz.Theme,

    fn callback(
        self: *Context,
        token: []const u8,
        scope: ?[]const u8,
    ) !void {
        const writer = std.io.getStdOut().writer();
        if (scope) |s| {
            if (self.theme.get(s)) |color| {
                try color.write(writer, "{s}", .{token});
                return;
            }
        }
        try writer.writeAll(token);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = try std.fs.cwd().readFileAlloc(
        allocator,
        "src/main.zig",
        10_000,
    );
    defer allocator.free(content);

    var ctx: Context = .{ .theme = lightz.DEFAULT_THEME };

    try lightz.walkHighlights(
        allocator,
        &ctx,
        Context.callback,
        content,
        .{ .lang = "zig" },
    );
}
