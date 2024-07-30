const std = @import("std");
const farbe = @import("farbe");

pub const FMT_NONE = farbe.ComptimeFarbe.init().fixed();

fn ThemeType(comptime T: type) type {
    return struct {
        attribute: ?T = null,
        character: ?T = null,
        comment: ?T = null,
        conditional: ?T = null,
        constant: ?T = null,
        exception: ?T = null,
        field: ?T = null,
        function: ?T = null,
        @"function.builtin": ?T = null,
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

fn SimpleTheme(comptime T: type) type {
    return struct {
        builtins: ?T = null,
        operators: ?T = null,
        types: ?T = null,
        literals: ?T = null,
        comments: ?T = null,
    };
}

pub const Theme = struct {
    const InnerType = ThemeType(farbe.Farbe);
    data: InnerType,

    pub fn initComptimeSimple(opts: SimpleTheme(farbe.ComptimeFarbe)) Theme {
        return innerInitSimple(opts);
    }

    pub fn initSimple(opts: SimpleTheme(farbe.Farbe)) Theme {
        return innerInitSimple(opts);
    }

    fn innerInitSimple(opts: anytype) Theme {
        return initComptime(.{
            .attribute = opts.builtins,
            .@"function.builtin" = opts.builtins,
            .keyword = opts.builtins,
            .repeat = opts.builtins,
            .conditional = opts.builtins,

            .exception = opts.operators,
            .operator = opts.operators,

            .type = opts.types,

            .string = opts.literals,
            .number = opts.literals,

            .comment = opts.comments,
        });
    }

    pub fn initComptime(theme: ThemeType(farbe.ComptimeFarbe)) Theme {
        return innerInit(theme);
    }

    pub fn init(theme: ThemeType(farbe.Fabre)) Theme {
        return innerInit(theme);
    }

    fn innerInit(theme: anytype) Theme {
        var data: InnerType = .{};

        inline for (@typeInfo(InnerType).Struct.fields) |field| {
            if (@field(theme, field.name)) |f| {
                @field(data, field.name) = f.fixed();
            }
        }

        return .{ .data = data };
    }

    pub fn get(theme: Theme, key: []const u8) ?farbe.Farbe {
        const short = if (std.mem.indexOfScalar(u8, key, '.')) |index|
            key[0..index]
        else
            key;
        var fallback_match: ?farbe.Farbe = null;

        inline for (@typeInfo(InnerType).Struct.fields) |field| {
            if (std.mem.eql(u8, key, field.name)) {
                return @field(theme.data, field.name) orelse FMT_NONE;
            } else if (std.mem.eql(u8, short, field.name)) {
                fallback_match = @field(theme.data, field.name) orelse FMT_NONE;
            }
        }
        return fallback_match;
    }
};

pub const DEFAULT_THEME = Theme.initComptimeSimple(
    .{
        .builtins = farbe.ComptimeFarbe.init().fgRgb(250, 120, 30).bold(),
        .operators = farbe.ComptimeFarbe.init().fgRgb(255, 255, 30),
        .types = farbe.ComptimeFarbe.init().fgRgb(64, 255, 255).bold(),
        .literals = farbe.ComptimeFarbe.init().fgRgb(255, 160, 160),
        .comments = farbe.ComptimeFarbe.init().fgRgb(138, 138, 138),
    },
);
