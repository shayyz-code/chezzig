const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "chezzig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // GUI target linking to system SDL2
    const gui = b.addExecutable(.{
        .name = "chezzig-gui",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gui.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    gui.linkSystemLibrary("SDL2");

    b.installArtifact(gui);

    const run_gui = b.addRunArtifact(gui);
    const gui_step = b.step("run-gui", "Run the GUI");
    gui_step.dependOn(&run_gui.step);
}
