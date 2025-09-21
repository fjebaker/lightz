const std = @import("std");
const lightz = @import("lightz");

const Context = struct {
    theme: lightz.Theme,

    fn callback(
        self: *Context,
        token: []const u8,
        scope: ?[]const u8,
    ) !void {
        var stdout = std.fs.File.stdout().writer(&.{});
        const writer = &stdout.interface;
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

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        var stderr = std.fs.File.stderr().writer(&.{});
        try stderr.interface.writeAll("Too few arguments: needs path and language");
        return;
    }

    const content = try std.fs.cwd().readFileAlloc(
        allocator,
        args[1],
        10_000,
    );
    defer allocator.free(content);

    var ctx: Context = .{ .theme = lightz.DEFAULT_THEME };

    var hl = lightz.HighlighterState.init(allocator);
    defer hl.deinit();

    try hl.highlight(
        &ctx,
        Context.callback,
        content,
        .{ .lang = args[2] },
    );
}
