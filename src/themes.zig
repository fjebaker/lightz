const std = @import("std");
const farbe = @import("farbe");

pub const FMT_NONE = farbe.Farbe.init();

pub const SimpleTheme = struct {
    builtins: ?farbe.Farbe = null,
    operators: ?farbe.Farbe = null,
    types: ?farbe.Farbe = null,
    literals: ?farbe.Farbe = null,
    comments: ?farbe.Farbe = null,
    functions: ?farbe.Farbe = null,
};

pub const Theme = struct {
    attribute: ?farbe.Farbe = null,
    character: ?farbe.Farbe = null,
    comment: ?farbe.Farbe = null,
    conditional: ?farbe.Farbe = null,
    constant: ?farbe.Farbe = null,
    exception: ?farbe.Farbe = null,
    field: ?farbe.Farbe = null,
    function: ?farbe.Farbe = null,
    @"function.builtin": ?farbe.Farbe = null,
    @"function.macro": ?farbe.Farbe = null,
    @"function.call": ?farbe.Farbe = null,
    keyword: ?farbe.Farbe = null,
    number: ?farbe.Farbe = null,
    operator: ?farbe.Farbe = null,
    parameter: ?farbe.Farbe = null,
    punctuation: ?farbe.Farbe = null,
    repeat: ?farbe.Farbe = null,
    string: ?farbe.Farbe = null,
    type: ?farbe.Farbe = null,
    variable: ?farbe.Farbe = null,

    pub fn initComptimeSimple(comptime opts: SimpleTheme) Theme {
        return innerInitSimple(opts);
    }

    pub fn initSimple(opts: SimpleTheme) Theme {
        return innerInitSimple(opts);
    }

    fn innerInitSimple(opts: anytype) Theme {
        return init(.{
            .attribute = opts.builtins,
            .@"function.builtin" = opts.builtins,
            .keyword = opts.builtins,
            .repeat = opts.builtins,
            .conditional = opts.builtins,

            .exception = opts.operators,
            .@"function.macro" = opts.operators,
            .operator = opts.operators,

            .@"function.call" = opts.functions,

            .type = opts.types,

            .string = opts.literals,
            .number = opts.literals,

            .comment = opts.comments,
        });
    }

    pub fn initComptime(comptime theme: Theme) Theme {
        return init(theme);
    }

    pub fn init(theme: Theme) Theme {
        return theme;
    }

    pub fn get(theme: Theme, key: []const u8) ?farbe.Farbe {
        const short = if (std.mem.indexOfScalar(u8, key, '.')) |index|
            key[0..index]
        else
            key;
        var fallback_match: ?farbe.Farbe = null;

        inline for (@typeInfo(Theme).Struct.fields) |field| {
            if (std.mem.eql(u8, key, field.name)) {
                return @field(theme, field.name) orelse FMT_NONE;
            } else if (std.mem.eql(u8, short, field.name)) {
                fallback_match = @field(theme, field.name) orelse FMT_NONE;
            }
        }
        return fallback_match;
    }
};

pub const DEFAULT_THEME = Theme.initComptimeSimple(
    .{
        .builtins = farbe.Farbe.init().fgRgb(250, 120, 30).bold(),
        .operators = farbe.Farbe.init().fgRgb(255, 255, 30),
        .types = farbe.Farbe.init().fgRgb(64, 255, 255).bold(),
        .literals = farbe.Farbe.init().fgRgb(255, 160, 160),
        .comments = farbe.Farbe.init().fgRgb(138, 138, 138),
        .functions = farbe.Farbe.init().fgRgb(0x7e, 0xa2, 0xff),
    },
);
