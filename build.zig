const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const box2d_dep = b.dependency("box2d", .{});

    const box2d_mod = b.addModule("box2d", .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    box2d_mod.addIncludePath(box2d_dep.path("include"));
    box2d_mod.addCSourceFiles(.{
        .root = box2d_dep.path("src"),
        .flags = &.{
            "-std=gnu17",
        },
        .files = &.{
            "aabb.c",
            "arena_allocator.c",
            "array.c",
            "bitset.c",
            "body.c",
            "broad_phase.c",
            "constraint_graph.c",
            "contact.c",
            "contact_solver.c",
            "core.c",
            "distance.c",
            "distance_joint.c",
            "dynamic_tree.c",
            "geometry.c",
            "hull.c",
            "id_pool.c",
            "island.c",
            "joint.c",
            "manifold.c",
            "math_functions.c",
            "motor_joint.c",
            "mouse_joint.c",
            "mover.c",
            "prismatic_joint.c",
            "revolute_joint.c",
            "sensor.c",
            "shape.c",
            "solver.c",
            "solver_set.c",
            "table.c",
            "timer.c",
            "types.c",
            "weld_joint.c",
            "wheel_joint.c",
            "world.c",
        },
    });

    const box2d_lib = b.addLibrary(.{
        .name = "box2d",
        .root_module = box2d_mod,
        // box2d stores some global state internally that is destroyed each reload if it is statically linked into game.dll
        .linkage = .dynamic,
    });
    box2d_lib.installHeadersDirectory(box2d_dep.path("include"), "", .{});
    b.installArtifact(box2d_lib);

    const testing = b.option(bool, "test", "Enable test applications (examples, benchmarks)") orelse false;
    if (!testing) return;

    const glfw_dep = b.lazyDependency("glfw", .{
        .target = target,
        .optimize = optimize,
    }) orelse return;
    const imgui_dep = b.lazyDependency("imgui", .{
        .target = target,
        .optimize = optimize,
    }) orelse return;
    const enki_dep = b.lazyDependency("enkits", .{
        .target = target,
        .optimize = optimize,
    }) orelse return;

    const samples_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });

    if (target.result.os.tag == .macos) {
        samples_mod.linkFramework("QuartzCore", .{});
    }

    samples_mod.linkLibrary(box2d_lib);
    samples_mod.addIncludePath(box2d_dep.path("shared"));
    samples_mod.addIncludePath(box2d_dep.path("extern/glad/include"));
    samples_mod.addIncludePath(box2d_dep.path("extern/jsmn"));
    samples_mod.addCSourceFiles(.{
        .flags = &.{
            "-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS",
            "-std=c++20",
        },
        .root = box2d_dep.path("samples"),
        .files = &.{
            "car.cpp",
            "donut.cpp",
            "doohickey.cpp",
            "draw.cpp",
            "main.cpp",
            "sample.cpp",
            "sample_benchmark.cpp",
            "sample_bodies.cpp",
            "sample_character.cpp",
            "sample_collision.cpp",
            "sample_continuous.cpp",
            "sample_determinism.cpp",
            "sample_events.cpp",
            "sample_geometry.cpp",
            "sample_joints.cpp",
            "sample_robustness.cpp",
            "sample_shapes.cpp",
            "sample_stacking.cpp",
            "sample_world.cpp",
            "shader.cpp",
        },
    });
    samples_mod.addCSourceFiles(.{
        .flags = &.{
            "-std=gnu17",
        },
        .root = box2d_dep.path("."),
        .files = &.{
            "extern/glad/src/glad.c",
            "shared/benchmarks.c",
            "shared/determinism.c",
            "shared/human.c",
            "shared/random.c",
        },
    });
    // Library dependencies
    samples_mod.addIncludePath(imgui_dep.path("."));
    samples_mod.addIncludePath(imgui_dep.path("backends"));
    samples_mod.addCSourceFiles(.{
        .flags = &.{
            "-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS",
            "-std=c++20",
        },
        .root = imgui_dep.path("."),
        .files = &.{
            "imgui.cpp",
            "imgui_draw.cpp",
            "imgui_demo.cpp",
            "imgui_tables.cpp",
            "imgui_widgets.cpp",
            "backends/imgui_impl_glfw.cpp",
            "backends/imgui_impl_opengl3.cpp",
        },
    });
    samples_mod.addIncludePath(glfw_dep.path("include"));
    samples_mod.linkLibrary(glfw_dep.artifact("glfw"));
    samples_mod.addIncludePath(enki_dep.path("src"));
    samples_mod.addCSourceFiles(.{
        .flags = &.{
            "-std=c++11",
        },
        .root = enki_dep.path("src"),
        .files = &.{
            "TaskScheduler.cpp",
            "TaskScheduler_c.cpp",
        },
    });

    const samples_exe = b.addExecutable(.{
        .name = "samples",
        .root_module = samples_mod,
    });

    b.installArtifact(samples_exe);
    b.installDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "samples/data",
        .source_dir = box2d_dep.path("samples/data"),
    });

    const run_cmd = b.addRunArtifact(samples_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    // TODO: don't hardcode prefix
    run_cmd.setCwd(b.path("zig-out"));

    const run_step = b.step("run", "Run example application");
    run_step.dependOn(&run_cmd.step);
}
