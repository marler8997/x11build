const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;
const Step = std.build.Step;
const RunStep = std.build.RunStep;

const which = @import("which.zig");
const GitRepoStep = @import("GitRepoStep.zig");


// nix-shell -p autoconf automake pkgconfig libtool
// unset CC
pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    //const mode = b.standardReleaseOptions();

    // todo: use this to detect whether we can execute binaries for the given target
    //const native_target_info = b.host.getExternalExecutor(
    // THIS IS GONE: const can_execute = builtin.target.canExecBinariesOf(target.getTarget());
    // until we implement this, this will just be a manual build option
    const can_execute = if (b.option(bool, "noexecute", "manually tell automake we can't execute binaries")) |n| !n else true;
    const automake_host: ?[]const u8 = if (can_execute) null else
        // TODO: is it ok to pass the zig triple as the --host to automake?
        (target.zigTriple(b.allocator) catch unreachable);

    var cc_bins = std.ArrayList([]const u8).init(b.allocator);

    var tools = findTools(b, target);

    // Add args to compiler here
    tools.cc.args = b.fmt("{s}"
        ++ " -nostdlib"
        ++ " -I/home/marler8997/git/ziglibc/inc/libc"
        ++ " -I/home/marler8997/git/ziglibc/inc/posix"
        ++ " -I/home/marler8997/git/ziglibc/inc/linux"
        ++ " -L/home/marler8997/git/ziglibc/zig-out/lib"
        ++ " -lstart"
        ++ " -lcguana",
        .{tools.cc.args},
    );
    std.log.info("CC=\"{s}\"", .{tools.cc.args});
    cc_bins.append(tools.cc.file) catch unreachable;
    var pkg_config_path_env: []const u8 = "PKG_CONFIG_PATH";

    const ld_bin: []const u8 = "ld";

    // I think gcc needs to have 'as' in PATH on Ubuntu but not on Nix?
    // TODO: I could create a test like autoconf does to see if gcc needs this?
    const on_ubuntu = if (b.option(bool, "ubuntu", "configure build for ubuntu")) |u| u else false;
    if (on_ubuntu) {
        cc_bins.append("as") catch unreachable;
    }
    const on_nixos = if (b.option(bool, "nixos", "configure for nixos")) |o| o else false;
    if (on_nixos) {
        pkg_config_path_env = "PKG_CONFIG_PATH_FOR_TARGET";
    }

    const env_path = b.pathFromRoot("env");
    const coreutils = &[_][]const u8 {
        // fs
        "rm", "mv", "mkdir", "ls", "cat", "cp", "touch",
        "ln", "ar", "ranlib", "chown", "chmod",
        "install", "dd", "find",
        // paths
        "dirname", "basename",
        // data manip
        "sort", "expr", "tr",
        "grep", "sed", "awk",
        "printf", "cut",
        // info
        "date", "uname",
        // misc
        "sleep",
    };

//    {
//        const autoconf_repo = GitRepoStep.create(b, .{
//            .url = "git://git.sv.gnu.org/autoconf",
//            .branch = "v2.71",
//            .sha = "5ec29d5a4991e1fee322a48e7358e5bcd17c645c",
//        });
//        b.step("autoconf", "autoconf").dependOn(&autoconf_repo.step);
//    }

    const containerize = true;

    const xcbproto_step = blk: {
        const repo = GitRepoStep.create(b, .{
            .url = "https://gitlab.freedesktop.org/xorg/proto/xcbproto",
            .branch = "xcb-proto-1.14.1",
            .sha = "496e3ce329c3cc9b32af4054c30fa0f306deb007",
        });
        const make = AutomakeStep.create(b, .{
            .name = "xcbproto",
            .path = repo.path,
            .host = automake_host,
        });
        make.step.dependOn(&repo.step);

        if (containerize) {
            const autogen_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "xcbproto-autogen" }),
                .binaries = coreutils ++ &[_][]const u8 {
                    "autoreconf",
                    "aclocal",
                    "automake",
                    "autoconf",
                    "python3",
                },
            });
            const make_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "xcbproto-make" }),
                .binaries = coreutils ++ &[_][]const u8 {
                    "make",
                },
            });

            make.step.dependOn(&autogen_env.step);
            make.autogen_step.setEnvironmentVariable("PATH", autogen_env.bin_path);
            make.step.dependOn(&make_env.step);
            make.make_step.setEnvironmentVariable("PATH", make_env.bin_path);
        }

        b.step("xcbproto", "xcbproto").dependOn(&make.step);
        break :blk make;
    };

    const xorg_macros_step = blk: {
        const repo = GitRepoStep.create(b, .{
            .url = "https://gitlab.freedesktop.org/xorg/util/macros",
            .branch = "util-macros-1.19.3",
            .sha = "b8766308d2f78bc572abe5198007cf7aeec9b761",
        });
        const make = AutomakeStep.create(b, .{
            .name = "xorg-macros",
            .path = repo.path,
            .host = automake_host,
        });
        make.step.dependOn(&repo.step);

        if (containerize) {
            const autogen_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "xcbproto-autogen" }),
                .binaries = coreutils ++ &[_][]const u8 {
                    "autoreconf",
                    "aclocal",
                    "automake",
                    "autoconf",
                    "python3",
                },
            });
            const make_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "xcbproto-make" }),
                .binaries = coreutils ++ &[_][]const u8 {
                    "make",
                },
            });

            make.step.dependOn(&autogen_env.step);
            make.autogen_step.setEnvironmentVariable("PATH", autogen_env.bin_path);
            make.step.dependOn(&make_env.step);
            make.make_step.setEnvironmentVariable("PATH", make_env.bin_path);
        }

        b.step("xorg-macros", "xorg-macros").dependOn(&make.step);
        break :blk make;
    };

    const xorgproto_step = blk: {
        const repo = GitRepoStep.create(b, .{
            .url = "https://gitlab.freedesktop.org/xorg/proto/xorgproto",
            .branch = "xorgproto-2021.5",
            .sha = "57acac1d4c7967f4661fb1c9f86f48f34a46c48d",
        });
        const make = AutomakeStep.create(b, .{
            .name = "xorgproto",
            .path = repo.path,
            .host = automake_host,
        });
        applyCCToAutomake(tools, make);
        make.step.dependOn(&repo.step);

        make.step.dependOn(&xorg_macros_step.step);
        make.autogen_step.setEnvironmentVariable("ACLOCAL",
            b.fmt("aclocal -I {s}/share/aclocal", .{xorg_macros_step.install_dir}));
        make.autogen_step.setEnvironmentVariable(pkg_config_path_env,
            b.fmt("{s}/share/pkgconfig", .{xorg_macros_step.install_dir}));

        if (containerize) {
            const autogen_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "xorgproto-autogen" }),
                .binaries = std.mem.concat(b.allocator, []const u8, &[_][]const []const u8{
                    coreutils,
                    &[_][]const u8 {
                        "pkg-config",
                        "autoreconf",
                        "aclocal",
                        "autom4te",
                        "automake",
                        "autoconf",
                        ld_bin,
                    },
                    cc_bins.items,
                }) catch unreachable,
            });
            const make_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "xorgproto-make" }),
                .binaries = std.mem.concat(b.allocator, []const u8, &[_][]const []const u8{
                    coreutils,
                    &[_][]const u8 {
                        "make",
                    },
                    cc_bins.items,
                }) catch unreachable,
            });

            make.step.dependOn(&autogen_env.step);
            make.autogen_step.setEnvironmentVariable("PATH", autogen_env.bin_path);
            make.step.dependOn(&make_env.step);
            make.make_step.setEnvironmentVariable("PATH", make_env.bin_path);
        }

        b.step("xorgproto", "xorgproto").dependOn(&make.step);
        break :blk make;
    };

    const xau_step = blk: {
        const repo = GitRepoStep.create(b, .{
            .url = "https://gitlab.freedesktop.org/xorg/lib/libxau",
            .branch = "libXau-1.0.9",
            .sha = "d9443b2c57b512cfb250b35707378654d86c7dea",
        });
        const make = AutomakeStep.create(b, .{
            .name = "libxau",
            .path = repo.path,
            .host = automake_host,
        });
        applyCCToAutomake(tools, make);
        make.step.dependOn(&repo.step);

        make.step.dependOn(&xorg_macros_step.step);
        make.step.dependOn(&xorgproto_step.step);
        make.autogen_step.setEnvironmentVariable("ACLOCAL",
            b.fmt("aclocal -I {s}/share/aclocal", .{xorg_macros_step.install_dir}));
        make.autogen_step.setEnvironmentVariable(pkg_config_path_env,
            b.fmt("{s}/share/pkgconfig", .{xorgproto_step.install_dir}));

        if (containerize) {
            const autogen_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "libxau-autogen" }),
                .binaries = std.mem.concat(b.allocator, []const u8, &[_][]const []const u8{
                    coreutils,
                    &[_][]const u8 {
                        "pkg-config",
                        "autoreconf",
                        "aclocal",
                        //"autom4te",
                        "automake",
                        "autoconf",
                        "libtoolize",
                        "m4", // or gm4 or gnum4
                        "make",
                        "nm",
                        ld_bin,
                    },
                    cc_bins.items,
                }) catch unreachable,
            });
            const make_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "libxau-make" }),
                .binaries = std.mem.concat(b.allocator, []const u8, &[_][]const []const u8{
                    coreutils,
                    &[_][]const u8 {
                        "make",
                        "autoheader",
                        "nm",
                        ld_bin,
                    },
                    cc_bins.items,
                }) catch unreachable,
            });

            make.step.dependOn(&autogen_env.step);
            make.autogen_step.setEnvironmentVariable("PATH", autogen_env.bin_path);
            make.step.dependOn(&make_env.step);
            make.make_step.setEnvironmentVariable("PATH", make_env.bin_path);
        }

        b.step("libxau", "libxau").dependOn(&make.step);
        break :blk make;
    };

    const xcb_step = blk: {
        const repo = GitRepoStep.create(b, .{
            .url = "https://gitlab.freedesktop.org/xorg/lib/libxcb",
            .branch = "libxcb-1.14",
            .sha = "4b40b44cb6d088b6ffa2fb5cf3ad8f12da588cef",
        });
        const make = AutomakeStep.create(b, .{
            .name = "libxcb",
            .path = repo.path,
            .host = automake_host,
        });
        applyCCToAutomake(tools, make);
        make.step.dependOn(&repo.step);

        make.step.dependOn(&xcbproto_step.step);
        make.step.dependOn(&xorg_macros_step.step);
        make.step.dependOn(&xorgproto_step.step);
        make.step.dependOn(&xau_step.step);
        make.autogen_step.setEnvironmentVariable("ACLOCAL",
            b.fmt("aclocal -I {s}/share/aclocal", .{xorg_macros_step.install_dir}));
        make.autogen_step.setEnvironmentVariable(
            pkg_config_path_env,
            b.fmt("{s}/lib/pkgconfig:{s}/share/pkgconfig:{s}/share/pkgconfig:{s}/lib/pkgconfig", .{
                xcbproto_step.install_dir,
                xorg_macros_step.install_dir,
                xorgproto_step.install_dir,
                xau_step.install_dir,
            }),
        );

        if (containerize) {
            const autogen_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "libxcb-autogen" }),
                .binaries = std.mem.concat(b.allocator, []const u8, &[_][]const []const u8{
                    coreutils,
                    &[_][]const u8 {
                        "pkg-config",
                        "autoreconf",
                        "aclocal",
                        "autom4te",
                        "automake",
                        "autoconf",
                        "libtoolize",
                        "m4", // or gm4 or gnum4
                        "python3",
                        "make",
                        ld_bin,
                    },
                    cc_bins.items,
                }) catch unreachable,
            });
            const make_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "libxcb-make" }),
                .binaries = std.mem.concat(b.allocator, []const u8, &[_][]const []const u8{
                    coreutils,
                    &[_][]const u8 {
                        "make",
                        "autoheader",
                        ld_bin,
                    },
                    cc_bins.items,
                }) catch unreachable,
            });

            make.step.dependOn(&autogen_env.step);
            make.autogen_step.setEnvironmentVariable("PATH", autogen_env.bin_path);
            make.step.dependOn(&make_env.step);
            make.make_step.setEnvironmentVariable("PATH", make_env.bin_path);
        }

        b.step("libxcb", "libxcb").dependOn(&make.step);
        break :blk make;
    };

    const xtrans_step = blk: {
        const repo = GitRepoStep.create(b, .{
            .url = "https://gitlab.freedesktop.org/xorg/lib/libxtrans",
            .branch = "xtrans-1.4.0",
            .sha = "c4262efc9688e495261d8b23a12f956ab38e006f",
        });
        const make = AutomakeStep.create(b, .{
            .name = "libxtrans",
            .path = repo.path,
            .host = automake_host,
        });
        applyCCToAutomake(tools, make);
        make.step.dependOn(&repo.step);

        make.step.dependOn(&xorg_macros_step.step);
        make.autogen_step.setEnvironmentVariable("ACLOCAL",
            b.fmt("aclocal -I {s}/share/aclocal", .{xorg_macros_step.install_dir}));

        if (containerize) {
            const autogen_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "libxtrans-autogen" }),
                .binaries = std.mem.concat(b.allocator, []const u8, &[_][]const []const u8{
                    coreutils,
                    &[_][]const u8 {
                        "autoreconf",
                        "aclocal",
                        "automake",
                        "autoconf",
                        "make",
                        ld_bin,
                    },
                    cc_bins.items,
                }) catch unreachable,
            });
            const make_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "libxtrans-make" }),
                .binaries = std.mem.concat(b.allocator, []const u8, &[_][]const []const u8{
                    coreutils,
                    &[_][]const u8 {
                        "make",
                    },
                }) catch unreachable,
            });

            make.step.dependOn(&autogen_env.step);
            make.autogen_step.setEnvironmentVariable("PATH", autogen_env.bin_path);
            make.step.dependOn(&make_env.step);
            make.make_step.setEnvironmentVariable("PATH", make_env.bin_path);
        }

        b.step("libxtrans", "libxtrans").dependOn(&make.step);
        break :blk make;
    };

    const x11_step = blk: {
        const repo = GitRepoStep.create(b, .{
            .url = "https://gitlab.freedesktop.org/xorg/lib/libx11",
            .branch = "libX11-1.7.3.1",
            .sha = "4c96f3567a8d045ee57b886fddc9618b71282530",
        });
        const make = AutomakeStep.create(b, .{
            .name = "libx11",
            .path = repo.path,
            .host = automake_host,
        });
        applyCCToAutomake(tools, make);
        make.step.dependOn(&repo.step);

        make.step.dependOn(&xorg_macros_step.step);
        make.step.dependOn(&xorgproto_step.step);
        make.step.dependOn(&xcb_step.step);
        make.step.dependOn(&xtrans_step.step);
        make.autogen_step.setEnvironmentVariable(
            "ACLOCAL",
            b.fmt("aclocal -I {s}/share/aclocal -I {s}/share/aclocal", .{
                xorg_macros_step.install_dir,
                xtrans_step.install_dir,
            }),
        );
        make.autogen_step.setEnvironmentVariable(
            pkg_config_path_env,
            b.fmt("{s}/share/pkgconfig:{s}/share/pkgconfig:{s}/lib/pkgconfig:{s}/share/pkgconfig", .{
                xorg_macros_step.install_dir,
                xorgproto_step.install_dir,
                xcb_step.install_dir,
                xtrans_step.install_dir,
            }),
        );

        if (containerize) {
            const autogen_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "libx11-autogen" }),
                .binaries = std.mem.concat(b.allocator, []const u8, &[_][]const []const u8{
                    coreutils,
                    &[_][]const u8 {
                        "pkg-config",
                        "autoreconf",
                        "aclocal",
                        "automake",
                        "autoconf",
                        "libtoolize",
                        "m4", // or gm4 or gnum4
                        "make",
                        ld_bin,
                        "cpp",
                    },
                    cc_bins.items,
                }) catch unreachable,
            });
            const make_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "libx11-make" }),
                .binaries = std.mem.concat(b.allocator, []const u8, &[_][]const []const u8{
                    coreutils,
                    &[_][]const u8 {
                        "make",
                        ld_bin,
                        "autoheader",
                    },
                    cc_bins.items,
                }) catch unreachable,
            });

            make.step.dependOn(&autogen_env.step);
            make.autogen_step.setEnvironmentVariable("PATH", autogen_env.bin_path);
            make.step.dependOn(&make_env.step);
            make.make_step.setEnvironmentVariable("PATH", make_env.bin_path);
        }
        // libxext depends on libx11, however, it also requires the Xauth.h
        // header, but, does not explicitly depend on libxau which is where
        // that header lives. This sound like a bug in libxext, however
        // for now I'm just going to install the Xauth.h header into the libx11
        // library.
        make.post_install_steps.append(&b.addInstallFileWithDir(
            .{ .path = b.fmt("{s}/include/X11/Xauth.h", .{xau_step.install_dir}) },
            .prefix,
            b.fmt("{s}/include/X11/Xauth.h", .{make.name}),
        ).step) catch unreachable;

        b.step("libx11", "libx11").dependOn(&make.step);
        break :blk make;
    };

    {
        const repo = GitRepoStep.create(b, .{
            .url = "https://gitlab.freedesktop.org/xorg/lib/libxext",
            .branch = "libXext-1.3.4",
            .sha = "ebb167f34a3514783966775fb12573c4ed209625",
        });
        const make = AutomakeStep.create(b, .{
            .name = "libxext",
            .path = repo.path,
            .host = automake_host,
        });
        applyCCToAutomake(tools, make);
        make.step.dependOn(&repo.step);

        make.step.dependOn(&xorg_macros_step.step);
        make.step.dependOn(&xorgproto_step.step);
        make.step.dependOn(&x11_step.step);
        make.autogen_step.setEnvironmentVariable(
            "ACLOCAL",
            b.fmt("aclocal -I {s}/share/aclocal", .{// -I {s}/share/aclocal", .{
                xorg_macros_step.install_dir,
                //xtrans_step.install_dir,
            }),
        );
        make.autogen_step.setEnvironmentVariable(
            pkg_config_path_env,
            b.fmt("{s}/share/pkgconfig:{s}/lib/pkgconfig", .{
                xorgproto_step.install_dir,
                x11_step.install_dir,
            }),
        );

        if (containerize) {
            const autogen_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "libxext-autogen" }),
                .binaries = std.mem.concat(b.allocator, []const u8, &[_][]const []const u8{
                    coreutils,
                    &[_][]const u8 {
                        "pkg-config",
                        "autoreconf",
                        "aclocal",
                        "automake",
                        "autoconf",
                        "libtoolize",
                        "m4", // or gm4 or gnum4
                        "make",
                        ld_bin,
//                        "cpp",
                    },
                    cc_bins.items,
                }) catch unreachable,
            });
            const make_env = ExplicitEnvStep.create(b, .{
                .path = b.pathJoin(&.{env_path, "libxext-make" }),
                .binaries = std.mem.concat(b.allocator, []const u8, &[_][]const []const u8{
                    coreutils,
                    &[_][]const u8 {
                        "make",
                        ld_bin,
                        "autoheader",
                    },
                    cc_bins.items,
                }) catch unreachable,
            });

            make.step.dependOn(&autogen_env.step);
            make.autogen_step.setEnvironmentVariable("PATH", autogen_env.bin_path);
            make.step.dependOn(&make_env.step);
            make.make_step.setEnvironmentVariable("PATH", make_env.bin_path);
        }

        b.step("libxext", "libxext").dependOn(&make.step);
    }
}

const AutomakeStep = struct {
    step: Step,
    name: []const u8,
    path: []const u8,
    install_dir: []const u8,
    autogen_done_file: []const u8,
    autogen_step: *RunStep,
    make_step: *RunStep,
    post_install_steps: std.ArrayList(*Step),

    pub fn create(b: *Builder, opt: struct {
        name: []const u8,
        path: []const u8,
        host: ?[]const u8,
    }) *AutomakeStep {
        const step = b.allocator.create(AutomakeStep) catch unreachable;

        const autogen_step = RunStep.create(b, b.fmt("autogen {s}", .{opt.name}));
        autogen_step.cwd = opt.path;
//        autogen_step.addArg("nix-shell");
//        autogen_step.addArg("--pure");
//        autogen_step.addArg("-p");
//        autogen_step.addArgs(opt.deps);
//        autogen_step.addArg("--run");
//
//        {
//            var run_cmd = ShellCmdBuilder.init(b.allocator);
//            defer run_cmd.deinit();
//            run_cmd.addArg(b.pathJoin(&.{opt.path, "autogen.sh"}));
//            run_cmd.addArg("--prefix");
//            // TODO: create install_prefix?
//            const install_dir = b.pathJoin(&.{b.install_prefix, opt.name});
//            run_cmd.addArg(install_dir);
//            autogen_step.addArg(run_cmd.toOwnedSlice());
//        }
        autogen_step.addArg(b.pathJoin(&.{opt.path, "autogen.sh"}));
        autogen_step.addArg("--prefix");
        const install_dir = b.pathJoin(&.{b.install_prefix, opt.name});
        autogen_step.addArg(install_dir);
        if (opt.host) |h| {
            autogen_step.addArg("--host");
            autogen_step.addArg(h);
        }

        const make_step = RunStep.create(b, b.fmt("make install {s}", .{opt.name}));
        make_step.cwd = opt.path;
//        make_step.addArg("nix-shell");
//        make_step.addArg("--pure");
//        make_step.addArg("-p");
//        make_step.addArgs(opt.deps);
//        make_step.addArg("--run");
//        make_step.addArg("make install");
        make_step.addArg("make");
        make_step.addArg("install");

        step.* = .{
            .step = Step.init(.custom, "AutomakeStep", b.allocator, make),
            .name = opt.name,
            .path = opt.path,
            .install_dir = install_dir,
            .autogen_done_file = b.pathJoin(&.{opt.path, "autogen-done"}),
            .autogen_step = autogen_step,
            .make_step = make_step,
            .post_install_steps = std.ArrayList(*Step).init(b.allocator),
        };
        return step;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(AutomakeStep, "step", step);

        // NOTE: currently the autogen step does not detect when it
        //       needs to re-run.  It will only detect whether it has
        //       already successfully ran.  To accomodate this I should
        //       probably add a build command to clean the autogen done files.
        // TODO: can we invalidate this done file when something changes?
        //       maybe before we call autogen, we can hash all the files
        //       (and keep a list of all the files that were hashed)
        //       or maybe there is already a way to do this in zig-cache?
        std.fs.accessAbsolute(self.autogen_done_file, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                try self.autogen_step.step.make();
                {
                    var file = try std.fs.createFileAbsolute(self.autogen_done_file, .{});
                    file.close();
                }
                // verify it now exists
                try std.fs.accessAbsolute(self.autogen_done_file, .{});
            },
            else => |e| return e,
        };
        try self.make_step.step.make();
        for (self.post_install_steps.items) |post_install_step| {
            try post_install_step.make();
        }
    }
};

const ShellCmdBuilder = struct {
    cmd: std.ArrayList(u8) = .{},
    pub fn init(allocator: std.mem.Allocator) ShellCmdBuilder {
        return .{ .cmd = std.ArrayList(u8).init(allocator) };
    }
    pub fn deinit(self: *ShellCmdBuilder) void {
        self.cmd.deinit();
    }
    pub fn toOwnedSlice(self: *ShellCmdBuilder) []const u8 {
        return self.cmd.toOwnedSlice();
    }
    pub fn addArg(self: *ShellCmdBuilder, arg: []const u8) void {
        // TODO: make this better
        if (self.cmd.items.len > 0) {
            self.cmd.append(' ') catch unreachable;
        }
        self.cmd.append('\'') catch unreachable;
        self.cmd.appendSlice(arg) catch unreachable;
        self.cmd.append('\'') catch unreachable;
    }
};

const ExplicitEnvStep = struct {
    step: Step,
    path: []const u8,
    binaries: []const []const u8,
    bin_path: []const u8,

    pub fn create(b: *Builder, opt: struct {
        path: []const u8,
        binaries: []const []const u8,
    }) *ExplicitEnvStep {
        const step = b.allocator.create(ExplicitEnvStep) catch unreachable;
        step.* = .{
            .step = Step.init(.custom, "ExplicitEnvStep", b.allocator, make),
            .path = opt.path,
            .binaries = opt.binaries,
            .bin_path = b.pathJoin(&.{ opt.path, "bin"}),
        };
        return step;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(ExplicitEnvStep, "step", step);

        // TODO do this within zig-cache
        try std.fs.cwd().deleteTree(self.path);
        try std.fs.cwd().makePath(self.path);
        try std.fs.cwd().makePath(self.bin_path);

        var bin_dir = try std.fs.cwd().openDir(self.bin_path, .{});
        defer bin_dir.close();

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const path = try std.process.getEnvVarOwned(arena.allocator(), "PATH");
        const pathext = if (builtin.os.tag == .windows) try std.process.getEnvVarOwned(arena.allocator(), "PATHEXT") else .{};
        for (self.binaries) |bin| {
            if (std.mem.containsAtLeast(u8, bin, 1, "/")) {
                if (!std.fs.path.isAbsolute(bin)) {
                    std.log.err("binary '{s}' must be an absolute path", .{bin});
                    std.os.exit(0xff);
                }
                try bin_dir.symLink(bin, std.fs.path.basename(bin), .{});
                continue;
            }
            const file = (try which.whichPathEnv(arena.allocator(), bin, path, pathext)) orelse {
                std.log.err("program '{s}' is not in PATH '{s}'", .{bin, path});
                return error.MissingProgram;
            };
            //std.log.info("symlink '{s}' -> '{s}'", .{bin, file});
            try bin_dir.symLink(file, bin, .{});
        }
        // add python3 for zignolibc
        bin_dir.access("python3", .{}) catch |err| switch (err) {
            error.FileNotFound => {
                const file = (try which.whichPathEnv(arena.allocator(), "python3", path, pathext)) orelse {
                    std.log.err("program '{s}' is not in PATH '{s}'", .{"python3", path});
                    return error.MissingProgram;
                };
                try bin_dir.symLink(file, "python3", .{});
            },
            else => |e| return e,
        };
    }
};

fn applyCCToAutomake(tools: Tools, make: *AutomakeStep) void {
    make.autogen_step.setEnvironmentVariable("CC", tools.cc.args);
    make.make_step.setEnvironmentVariable("CC", tools.cc.args);
}

const Tool = struct {
    file: []const u8,
    args: []const u8,
};
const Tools = struct {
    cc: Tool,
    ar: Tool,
};
fn findTools(b: *std.build.Builder, target: std.zig.CrossTarget) Tools {
    if (std.process.getEnvVarOwned(b.allocator, "CC")) |cc| {
        const file_limit = std.mem.indexOfScalar(u8, cc, ' ') orelse cc.len;
        return .{
            .cc = .{
                .file = cc[0 .. file_limit],
                .args = cc,
            },
            .ar = .{
                .file = "ar", // maybe it will work?
                .args = "ar",
            },
         };
    } else |err| switch (err) {
        error.EnvironmentVariableNotFound => {},
        else => unreachable,
    }
    if (target.isNative()) {
        std.log.err("specify a cross target with -Dtarget=..., otherwise, zig tries to find the system libc headers/libs and can fail", .{});
        std.os.exit(0xff);
    }
    const zig_no_libc = "/home/marler8997/git/x11build/zignolibc";
    return .{
        .cc = .{
            .file = zig_no_libc,
            .args = b.fmt("{s} cc -target {s}", .{zig_no_libc, target.zigTriple(b.allocator) catch unreachable}),
        },
        .ar = .{
            .file = b.zig_exe,
            .args = b.fmt("{s} ar", .{b.zig_exe}),
        }
    };

//    const path = std.process.getEnvVarOwned(b.allocator, "PATH") catch |err| switch (err) {
//        error.EnvironmentVariableNotFound => "",
//        else => unreachable,
//    };
//    defer b.allocator.free(path);
//    const pathext = if (builtin.os.tag == .windows) try std.process.getEnvVarOwned(b.allocator, "PATHEXT") else .{};
//    const file = (which.whichPathEnv(b.allocator, "gcc", path, pathext) catch unreachable) orelse {
//        std.log.err("cannot find 'gcc' in PATH, and 'zig cc' does not work yet", .{});
//        std.os.exit(0xff);
//    };
//    return .{
//        .file = file,
//        .env = file,
//    };
}

const SystemTestsStep = struct {
    step: Step,
    pub fn create(b: *Builder, opt: struct {
        placeholder: u32 = 0,
    }) *SystemTestsStep {
        _ = opt;
        const step = b.allocator.create(ExplicitEnvStep) catch unreachable;
        step.* = .{
            .step = Step.init(.custom, "SystemTestsStep", b.allocator, make),
        };
        return step;
    }
    fn make(step: *Step) !void {
        _ = step;
        @panic("todo");
    }
};
