// TODO: this stuff should be moved to the std library
const std = @import("std");
const builtin = @import("builtin");

pub const PathExt = if (builtin.os.tag == .windows) []const u8 else struct { };

pub fn whichPathEnv(allocator: std.mem.Allocator, prog: []const u8, path_env: []const u8, env: PathExt) !?[:0]u8 {
    if (builtin.os.tag == .windows) {
        var path_it = std.mem.split(u8, path_env, ";");
        while (path_it.next()) |dir| {
            var ext_it = std.mem.split(u8, env, ";");
            while (ext_it.next()) |ext| {
                // TODO: change this to 1 allocation instead of 2
                const file = blk: {
                    const basename = try std.mem.concat(allocator, u8, &.{ prog, ext });
                    defer allocator.free(basename);
                    break :blk try std.fs.path.joinZ(allocator, &.{ dir, basename });
                };
                std.fs.cwd().accessZ(file, .{}) catch {
                    allocator.free(file);
                    continue;
                };
                return file;
            }
        }
        return null;
    } else {
        var it = std.mem.split(u8, path_env, ":");
        while (it.next()) |dir| {
            const file = try std.fs.path.joinZ(allocator, &.{ dir, prog });
            std.fs.cwd().accessZ(file, .{}) catch {
                allocator.free(file);
                continue;
            };
            return file;
        }
    }
    return null;
}
