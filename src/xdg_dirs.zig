//! This file contains functions and types for working with Linux desktop directories,
//! according to the XDG Basedir Specification.

const std = @import("std");

/// Desktop directories according to
/// [XDG Basedir Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
pub const XdgDirType = enum {
    /// User-specific data files
    user_data,
    /// User-specific configuration data
    user_config,
    /// User-specific state data
    user_state,
    /// User-specific cache
    user_cache,
    /// User-specific runtime files
    user_runtime,
    /// Set of preference ordered data file dirs
    data,
    /// Set of preference ordered configuration dirs
    config,

    /// Returns the name of an environment variable corresponding to `self`
    pub fn getEnvVarName(comptime self: XdgDirType) []const u8 {
        return switch (self) {
            .user_data => "XDG_DATA_HOME",
            .user_config => "XDG_CONFIG_HOME",
            .user_state => "XDG_STATE_HOME",
            .user_cache => "XDG_CACHE_HOME",
            .user_runtime => "XDG_RUNTIME_DIR",
            .data => "XDG_DATA_DIRS",
            .config => "XDG_CONFIG_DIRS",
        };
    }

    /// Returns a default XDG directory that is used when the corresponding
    /// environment variable is empty or not set as stated in XDG specification.
    pub fn getDefaultPath(comptime self: XdgDirType) []const u8 {
        return switch (self) {
            .user_data => ".local/share",
            .user_config => ".config",
            .user_state => ".local/state",
            .user_cache => ".cache",
            .user_runtime => "/run/user",
            .data => "usr/local/share:/usr/share",
            .config => "/etc/xdg",
        };
    }
};

fn getUidString(allocator: std.mem.Allocator) []const u8 {
    const uid = std.os.linux.getuid();
    return std.fmt.allocPrint(allocator, "{d}", .{uid}) catch unreachable;
}

/// Returns a default runtime directory according to the XDG Basedir Specification.
/// Caller owns the memory.
pub fn getXdgRuntimeDirDefault(allocator: std.mem.Allocator) []const u8 {
    const runtime_path = comptime XdgDirType.getDefaultPath(.user_runtime);
    const uid = getUidString(allocator);
    return std.fs.path.join(allocator, &[_][]const u8{ runtime_path, uid });
}

/// Returns an environment-defined path corresponding to `kind`, orelse returns
/// a default for `kind`. Retunrs an error if the path stored in the environment variable
/// is not absolute.
pub fn getXdgDir(kind: XdgDirType) ![]const u8 {
    const path = std.os.getenv(kind.getEnvVarName()) orelse kind.getDefaultPath();

    if (!std.fs.path.isAbsolute(path))
        return error.XdgPathMustBeAbsolute;
    return path;
}

/// Opens an XDG directory and returns the handle.
pub fn openXdgDir(kind: XdgDirType) !std.fs.Dir {
    return std.fs.openDirAbsolute(try getXdgDir(kind));
}
