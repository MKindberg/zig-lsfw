const std = @import("std");

pub fn build(b: *std.Build) void {
    // Build the server
    const exe = b.addExecutable(.{
        .name = "server_name",
        .root_source_file = b.path("src/main.zig"),
    });

    // Add the dependency towards lsfw
    const lsfw = b.dependency("lsfw", .{});

    // Allow the server to import the lsp module from lsfw
    const lsp = lsfw.module("lsp");
    exe.root_module.addImport("lsp", lsp);

    b.installArtifact(exe);

    // Create a build target for generating minimal editor plugins
    const plugin_generator = b.addExecutable(.{
        .name = "generate_plugins",
        .root_source_file = b.path("plugin_generator.zig"),
        .target = b.host,
    });
    plugin_generator.root_module.addImport("lsp_plugins", lsfw.module("plugins"));
    b.step("gen_plugins", "Generate plugins").dependOn(&b.addRunArtifact(plugin_generator).step);
}
