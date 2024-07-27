const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const treez_shared = b.dependency("treez-shared", .{ .target = target, .optimize = optimize });
    // which languages to build
    // specific languages can be built with `.lang=&.{.zig, .c, .julia}`
    // or can specify all as below
    const langs = b.dependency("treez-shared", .{
        .target = target,
        .optimize = optimize,
        .all = true,
        .extdir = b.lib_dir,
    });
    langs.builder.lib_dir = b.lib_dir;
    b.getInstallStep().dependOn(langs.builder.getInstallStep());

    const farbe = b.dependency(
        "farbe",
        .{ .target = target, .optimize = optimize },
    );

    const treez_module = treez_shared.module("treez-shared");

    const lib = b.addStaticLibrary(.{
        .name = "lightz",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "lightz",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("treez", treez_module);
    exe.root_module.addImport("farbe", farbe.module("farbe"));

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
