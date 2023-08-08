const std = @import("std");

const Allocator = std.mem.Allocator;

const Requirements = @This();

pub const Char = struct {
    char: u21,
    pos: ?usize,
};

len: usize,
info: std.ArrayList(Char),

pub fn init(allocator: Allocator, len: usize) !Requirements {
    return Requirements{
        .len = len,
        .info = std.ArrayList(Char).init(allocator),
    };
}

pub fn deinit(self: Requirements) void {
    self.info.deinit();
}

/// caller owns returned memory
pub fn toWord(self: Requirements, allocator: Allocator) ![]const u21 {
    const word = try allocator.alloc(u21, self.len);
    @memset(word, '_');
    for (self.info.items) |info| {
        word[info.pos orelse continue] = info.char;
    }
    return word;
}

pub fn containsInfoOn(self: Requirements, char: u21) bool {
    for (self.info.items) |c| {
        if (char == c.char) {
            return true;
        }
    }
    return false;
}

pub fn append(self: *Requirements, char: u21, pos: ?usize) !void {
    for (self.info.items) |info| {
        if (info.pos == pos) {
            return error.CharacterAlreadyKnown;
        }
    }
    try self.info.append(Char{ .pos = pos, .char = char });
}

pub fn validChars(self: Requirements) usize {
    var n: usize = 0;
    for (self.info.items) |char| {
        if (char.pos) |_| {
            n += 1;
        }
    }
    return n;
}
