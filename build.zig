const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule( "lsp", .{
        .root_source_file = b.path("src/lsp.zig"),
        .target = target,
        .optimize = optimize,
    });

}
