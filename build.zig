const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const zig_fsrs_module = b.addModule("zig-fsrs", .{
        .root_source_file = b.path("src/zig-fsrs.zig"),
        .target = target,
        .optimize = optimize,
    });

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
