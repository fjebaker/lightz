const std = @import("std");
const farbe = @import("farbe");
const treez = @import("treez");

pub const themes = @import("themes.zig");
pub const Theme = themes.Theme;
pub const DEFAULT_THEME = themes.DEFAULT_THEME;

fn CallBack(comptime T: type) type {
    return fn (
        ctx: T,
        sel: treez.Range,
        scope: []const u8,
        id: u32,
        capture_idx: usize,
    ) anyerror!void;
}

pub const SyntaxHighlighter = struct {
    allocator: std.mem.Allocator,
    lang_spec: *treez.LanguageSpec,
    parser: *treez.Parser,
    query: *treez.Query,
    tree: ?*treez.Tree = null,

    fn parse(self: *SyntaxHighlighter, content: []const u8) !void {
        if (self.tree) |tree| tree.destroy();
        self.tree = try self.parser.parseString(null, content);
    }

    pub fn init(
        allocator: std.mem.Allocator,
        lang_spec: *treez.LanguageSpec,
    ) !SyntaxHighlighter {
        var self: SyntaxHighlighter = .{
            .allocator = allocator,
            .lang_spec = lang_spec,
            .parser = try treez.Parser.create(),
            .query = try treez.Query.create(lang_spec.lang, lang_spec.highlights),
        };
        errdefer self.deinit();
        try self.parser.setLanguage(lang_spec.lang);
        return self;
    }

    pub fn deinit(self: *SyntaxHighlighter) void {
        if (self.tree) |t| t.destroy();
        self.query.destroy();
        self.parser.destroy();
    }

    pub fn walk(
        self: *SyntaxHighlighter,
        ctx: anytype,
        comptime cb: CallBack(@TypeOf(ctx)),
        content: []const u8,
    ) !void {
        try self.parse(content);
        const cursor = try treez.Query.Cursor.create();
        defer cursor.destroy();
        const tree = if (self.tree) |p| p else return;
        cursor.execute(self.query, tree.getRootNode());
        while (cursor.nextMatch()) |match| {
            var idx: usize = 0;
            for (match.captures()) |capture| {
                try cb(
                    ctx,
                    capture.node.getRange(),
                    self.query.getCaptureNameForId(capture.id),
                    capture.id,
                    idx,
                );
                idx += 1;
            }
        }
    }
};

pub fn DrawCallback(comptime T: type) type {
    return fn (
        ctx: T,
        token: []const u8,
        scope: ?[]const u8,
    ) anyerror!void;
}

pub const HighlightOptions = struct {
    lang: []const u8,
    ext_dir: std.fs.Dir = std.fs.cwd(),
};

fn WrapHighlightCallback(comptime T: type, comptime funcT: anytype) type {
    return struct {
        const Ctx = @This();

        inner_ctx: T,
        content: []const u8,
        end_byte: usize = 0,

        pub fn inner(
            self: *Ctx,
            range: treez.Range,
            scope: []const u8,
            id: u32,
            idx: usize,
        ) anyerror!void {
            _ = id;
            if (idx > 0) return;

            if (self.end_byte < range.start_byte) {
                const slice = self.content[self.end_byte..range.start_byte];
                try funcT(self.inner_ctx, slice, null);
                self.end_byte = range.start_byte;
            }

            if (range.start_byte < self.end_byte) return;
            const slice = self.content[range.start_byte..range.end_byte];
            try funcT(self.inner_ctx, slice, scope);
            self.end_byte = range.end_byte;
        }
    };
}

pub fn walkHighlights(
    allocator: std.mem.Allocator,
    ctx: anytype,
    cb: DrawCallback(@TypeOf(ctx)),
    content: []const u8,
    opts: HighlightOptions,
) !void {
    var lang_spec = try treez.load_language_extension(
        allocator,
        opts.ext_dir,
        .{ .name = opts.lang },
    );
    defer lang_spec.deinit();

    var parser = try SyntaxHighlighter.init(allocator, &lang_spec);
    defer parser.deinit();

    const OuterCtx = WrapHighlightCallback(@TypeOf(ctx), cb);
    var outer_ctx: OuterCtx = .{
        .inner_ctx = ctx,
        .content = content,
    };

    try parser.walk(&outer_ctx, OuterCtx.inner, content);
}
