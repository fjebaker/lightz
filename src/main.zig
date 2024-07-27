const std = @import("std");
const treez = @import("treez");
const farbe = @import("farbe");

const FMT_NONE = farbe.ComptimeFarbe.init().fixed();

pub fn ThemeType(comptime T: type) type {
    return struct {
        attribute: ?T = null,
        character: ?T = null,
        comment: ?T = null,
        conditional: ?T = null,
        constant: ?T = null,
        exception: ?T = null,
        field: ?T = null,
        function: ?T = null,
        keyword: ?T = null,
        number: ?T = null,
        operator: ?T = null,
        parameter: ?T = null,
        punctuation: ?T = null,
        repeat: ?T = null,
        string: ?T = null,
        type: ?T = null,
        variable: ?T = null,
    };
}

pub const Theme = struct {
    const InnerType = ThemeType(farbe.Farbe);
    data: InnerType,

    pub fn initComptime(theme: ThemeType(farbe.ComptimeFarbe)) Theme {
        var data: InnerType = .{};

        inline for (@typeInfo(InnerType).Struct.fields) |field| {
            if (@field(theme, field.name)) |f| {
                @field(data, field.name) = f.fixed();
            }
        }

        return .{ .data = data };
    }

    pub fn get(theme: Theme, key: []const u8) ?farbe.Farbe {
        inline for (@typeInfo(InnerType).Struct.fields) |field| {
            if (std.mem.eql(u8, key, field.name)) {
                return @field(theme.data, field.name) orelse FMT_NONE;
            }
        }
        return null;
    }
};

const color_scheme = Theme.initComptime(
    .{
        .keyword = farbe.ComptimeFarbe.init().fgRgb(250, 120, 30).bold(),
        .attribute = farbe.ComptimeFarbe.init().fgRgb(250, 120, 30).bold(),
        .repeat = farbe.ComptimeFarbe.init().fgRgb(250, 120, 30).bold(),
        .conditional = farbe.ComptimeFarbe.init().fgRgb(250, 120, 30).bold(),

        .exception = farbe.ComptimeFarbe.init().fgRgb(255, 255, 30).bold(),
        .operator = farbe.ComptimeFarbe.init().fgRgb(255, 255, 30),

        .type = farbe.ComptimeFarbe.init().fgRgb(64, 255, 255).bold(),

        .string = farbe.ComptimeFarbe.init().fgRgb(255, 160, 160),
        .number = farbe.ComptimeFarbe.init().fgRgb(255, 160, 160),
        .comment = farbe.ComptimeFarbe.init().fgRgb(138, 138, 138),
    },
);

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
        var dir = try std.fs.cwd().openDir("zig-out/lib/", .{});
        defer dir.close();
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

const Ctx = struct {
    content: []const u8,
    end_byte: usize = 0,
    theme: Theme,

    fn print_call_back(
        self: *Ctx,
        range: treez.Range,
        scope: []const u8,
        id: u32,
        idx: usize,
    ) !void {
        const writer = std.io.getStdOut().writer();
        _ = id;
        if (idx > 0) return;

        if (self.end_byte < range.start_byte) {
            const slice = self.content[self.end_byte..range.start_byte];
            try writer.writeAll(slice);
            self.end_byte = range.start_byte;
        }

        if (range.start_byte < self.end_byte) return;

        const slice = self.content[range.start_byte..range.end_byte];
        const spec = if (std.mem.indexOfScalar(u8, scope, '.')) |index|
            scope[0..index]
        else
            scope;

        if (self.theme.get(spec)) |fmt| {
            try fmt.write(writer, "{s}", .{slice});
        } else {
            std.debug.print("> UNHANDLED: {s}\n", .{spec});
        }

        self.end_byte = range.end_byte;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // the directory where the shared object and .scm files are
    var dir = try std.fs.cwd().openDir("zig-out/lib/", .{});
    defer dir.close();

    // dynamically load the language extension
    var lang_spec = try treez.load_language_extension(
        allocator,
        dir,
        .{ .name = "zig" },
    );
    defer lang_spec.deinit();

    const content = try std.fs.cwd().readFileAlloc(
        allocator,
        "src/main.zig",
        10_000,
    );
    defer allocator.free(content);

    var parser = try SyntaxHighlighter.init(allocator, &lang_spec);
    defer parser.deinit();

    var ctx: Ctx = .{
        .content = content,
        .theme = color_scheme,
    };
    try parser.walk(&ctx, Ctx.print_call_back, content);
}
