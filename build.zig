const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const treez_shared = b.dependency("shared-treez", .{
        .target = target,
        .optimize = optimize,
        .@"ext-all" = true,
        .@"ext-directory" = b.lib_dir,
        .@"ext-type" = .static,
    });
    treez_shared.builder.lib_dir = b.lib_dir;
    b.getInstallStep().dependOn(treez_shared.builder.getInstallStep());

    const farbe = b.dependency(
        "farbe",
        .{ .target = target, .optimize = optimize },
    );

    const treez_module = treez_shared.module("shared-treez");

    const mod = b.addModule(
        "lightz",
        .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "treez", .module = treez_module },
                .{ .name = "farbe", .module = farbe.module("farbe") },
            },
        },
    );

    const exe = b.addExecutable(.{
        .name = "lightz",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("lightz", mod);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
