const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    // Module
    const zig_fsrs_module = b.addModule("zig-fsrs", .{
        .root_source_file = b.path("src/zig-fsrs.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Examples
    const Example = enum { simple, tui };
    const example_option = b.option(Example, "example", "Example to run (default: simple)") orelse .simple;
    const example_step = b.step("example", "Run example");
    const example = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path(
            b.fmt("examples/{s}.zig", .{@tagName(example_option)}),
        ),
        .target = target,
        .optimize = optimize,
    });
    example.root_module.addImport("zig-fsrs", zig_fsrs_module);
    // TODO: vaxis is not needed on examples without tui,
    // find another way to conditionally add it only if tui is used
    // reference: https://github.com/zigzap/zap/blob/master/build.zig
    const vaxis_dep = b.lazyDependency("vaxis", .{
        .optimize = optimize,
        .target = target,
    });
    if (vaxis_dep) |dep| example.root_module.addImport("vaxis", dep.module("vaxis"));

    const example_run = b.addRunArtifact(example);
    example_step.dependOn(&example_run.step);

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    tests.root_module.addImport("zig-fsrs", zig_fsrs_module);
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
