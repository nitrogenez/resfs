const std = @import("std");
const log = std.log.scoped(.resfs);
const filetype_map = @import("filetype_map.zig");

test {
    _ = xdg_dirs;
}

pub const xdg_dirs = @import("xdg_dirs.zig");

pub const sep = std.fs.path.sep_str;

const root = @import("root");
const override = if (@hasDecl(root, "resfs_dirs")) root.resfs_dirs else struct {};

/// A list of paths to directories that resfs refers to when
/// looking up resources. Every path is obtained from joining `ResFs`'s root_path and
/// any path relative to `assets_path`.
pub const dirs = struct {
    /// Root path to all the resources that are managed by the library.
    pub const assets_path: []const u8 = if (@hasDecl(override, "assets_path"))
        override.assets_path
    else
        "assets";

    pub const bin_path: []const u8 = if (@hasDecl(override, "bin_path"))
        override.bin_path
    else
        assets_path ++ sep ++ "bin";

    /// Path to audio resources. Must be inside the `assets_path`.
    pub const audio_path = if (@hasDecl(override, "audio_path"))
        override.audio_path
    else
        assets_path ++ sep ++ "audio";

    /// Path to sound effects. Should logically be inside `audio_path`.
    pub const sfx_path = if (@hasDecl(override, "sfx_path"))
        override.sfx_path
    else
        audio_path ++ sep ++ "sfx";

    /// Path to music files. Should logically be inside `audio_path`.
    pub const music_path = if (@hasDecl(override, "music_path"))
        override.music_path
    else
        audio_path ++ sep ++ "music";

    /// Path to video files.
    pub const videos_path = if (@hasDecl(override, "videos_path"))
        override.videos_path
    else
        assets_path ++ sep ++ "videos";

    /// Path to image files.
    pub const images_path = if (@hasDecl(override, "images_path"))
        override.images_path
    else
        assets_path ++ sep ++ "images";

    /// Path to textures. Logically should be inside `images_path`.
    pub const textures_path = if (@hasDecl(override, "textures_path"))
        override.textures_path
    else
        images_path ++ sep ++ "textures";

    /// Path to sprites. Logically should be inside `images_path`.
    pub const sprites_path = if (@hasDecl(override, "sprites_path"))
        override.sprites_path
    else
        images_path ++ sep ++ "sprites";

    /// Path to 3D models (.obj, .fbx, etc.).
    pub const models_path = if (@hasDecl(override, "models_path"))
        override.models_path
    else
        assets_path ++ sep ++ "models";

    /// Path to scripts (any text file).
    pub const scripts_path = if (@hasDecl(override, "scripts_path"))
        override.scripts_path
    else
        assets_path ++ sep ++ "scripts";

    /// Path to misc resources.
    pub const misc_path = if (@hasDecl(override, "misc_path"))
        override.misc_path
    else
        assets_path ++ sep ++ "misc";
};

const ResFs = @This();

pub const ResourceType = enum {
    unknown,
    asset,
    bin,
    audio,
    sfx,
    music,
    image,
    video,
    texture,
    sprite,
    model,
    script,
    misc,

    pub fn fromText(s: []const u8) ResourceType {
        return inline for (@typeInfo(ResourceType).Enum.fields) |f| if (std.mem.eql(u8, s, f.name))
            @as(ResourceType, @enumFromInt(f.value));
    }

    pub fn fromExtension(s: []const u8) ResourceType {
        const ext = std.fs.path.extension(s);

        if (filetype_map.image_extensions.has(ext))
            return .image;
        if (filetype_map.video_extensions.has(ext))
            return .video;
        if (filetype_map.audio_extensions.has(ext))
            return .audio;
        // if (filetype_map.code_extensions.has(ext))
        //     return .script;
        // // if (filetype_map.model_extensions.has(ext))
        //     return .model;
        return .asset;
    }

    pub fn getPath(self: ResourceType) ?[]const u8 {
        return switch (self) {
            .asset => dirs.assets_path,
            .audio => dirs.audio_path,
            .sfx => dirs.sfx_path,
            .music => dirs.music_path,
            .image => dirs.images_path,
            .video => dirs.videos_path,
            .texture => dirs.textures_path,
            .sprite => dirs.sprites_path,
            .model => dirs.models_path,
            .script => dirs.scripts_path,
            .misc => dirs.misc,
            .bin => dirs.bin_path,
            else => null,
        };
    }
};

arena: std.heap.ArenaAllocator,
root_path: []const u8,
root_handle: ?std.fs.Dir = null,

pub fn init(allocator: std.mem.Allocator, cwd: bool) !ResFs {
    var arena = std.heap.ArenaAllocator.init(allocator);
    var buf: [std.fs.MAX_PATH_BYTES]u8 = [_]u8{0} ** std.fs.MAX_PATH_BYTES;

    const path = if (!cwd) try std.fs.selfExeDirPathAlloc(arena.allocator()) else blk: {
        const bytes = try std.os.getcwd(&buf);
        break :blk try allocator.dupe(u8, bytes);
    };
    return .{
        .arena = arena,
        .root_path = path,
        .root_handle = try std.fs.cwd().openDir(path),
    };
}

pub fn deinit(self: *ResFs) void {
    self.arena.deinit();
    self.root_handle.?.close();
    self.* = undefined;
}

pub fn expandUri(self: *ResFs, uri: []const u8) ![]const u8 {
    const p_uri = try std.Uri.parse(uri);
    const r_path = ResourceType.fromText(p_uri.scheme).getPath() orelse return error.UnknownResourceType;

    return std.fs.path.join(self.arena, &[_][]const u8{ self.root_path, r_path, p_uri.path });
}

pub fn expandUriAndOpen(self: *ResFs, uri: []const u8, open_flags: std.fs.File.OpenFlags) !std.fs.Dir {
    return std.fs.cwd().openFile(try self.expandUri(uri), open_flags);
}

pub const getAssetPath = expandUri;
pub const getAsset = expandUriAndOpen;

test "fromExtension" {
    var t = try std.time.Timer.start();
    try std.testing.expect(ResourceType.fromExtension("py") == .asset);
    std.debug.print("\n\ntook {d}ms", .{std.time.ns_per_ms / t.lap()});
}
