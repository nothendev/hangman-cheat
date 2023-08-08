const std = @import("std");
const unicode = std.unicode;
const math = std.math;
const mem = std.mem;
const util = @import("util.zig");

const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const Requirements = @import("Requirements.zig");

const Words = @This();

words: std.ArrayList([]const u8),

pub fn init(allocator: Allocator) Words {
    return Words{ .words = std.ArrayList([]const u8).init(allocator) };
}

pub fn deinit(self: *Words) void {
    self.words.deinit();
}

pub fn addFile(self: *Words, fcontents: []const u8) !void {
    var iter = mem.split(u8, fcontents, "\n");
    while (iter.next()) |word| {
        if (word.len == 0) {
            continue;
        }
        try self.words.append(word);
    }
}

pub fn mostCommonChar(self: Words, reqs: Requirements) !u21 {
    if (self.words.items.len == 0) {
        return error.EmptyList;
    }
    var chars = [_]usize{0} ** math.maxInt(u8);
    for (self.words.items) |word| {
        for (word) |char| {
            if (reqs.containsInfoOn(util.utf8.toLower(char))) {
                continue;
            }
            chars[util.utf8.toLower(char)] += 1;
        }
    }

    var char: u21 = 0;
    var most_common: usize = 0;
    for (chars, 0..) |n, i| {
        if (n > most_common) {
            char = @intCast(i);
        }
        most_common = @max(n, most_common);
    }

    switch (char) {
        0 => unreachable,
        'A'...'Z' => unreachable,
        else => {},
    }

    return char;
}

pub fn removeUnsuitable(
    self: *Words,
    reqs: Requirements,
) !void {
    try self.removeUnequalLength(reqs);

    for (reqs.info.items) |info| {
        var check_buf = [_]bool{false} ** math.maxInt(u8);
        var checklist = check_buf[0..reqs.len];

        for (reqs.info.items) |_info| {
            if (info.char == _info.char) {
                checklist[_info.pos orelse continue] = true;
            }
        }

        var idx: usize = 0;
        while (idx < self.words.items.len) {
            var i: usize = 0;
            var iter = unicode.Utf8Iterator{ .bytes = self.words.items[idx], .i = 0 };
            const match = while (iter.nextCodepoint()) |cp| : (i += 1) {
                if ((info.char == util.utf8.toLower(cp)) != checklist[i]) {
                    break false;
                }
            } else true;

            if (match) {
                idx += 1;
            } else {
                _ = self.words.swapRemove(idx);
            }
        }
    }

    if (self.words.items.len < 100) {
        self.removeDuplicates();
    }
}

fn removeUnequalLength(self: *Words, reqs: Requirements) !void {
    var idx: usize = 0;
    while (idx < self.words.items.len) {
        if (try unicode.calcUtf16LeLen(self.words.items[idx]) != reqs.len) {
            _ = self.words.swapRemove(idx);
        } else {
            idx += 1;
        }
    }
}

pub fn removeDuplicates(self: *Words) void {
    assert(self.words.items.len < 100); // this operation is O(n^2), do not use on larger data sets

    var idx: usize = 0;
    while (idx < self.words.items.len) {
        for (self.words.items, 0..) |word, _idx| {
            if (mem.eql(u8, self.words.items[idx], word) and idx != _idx) {
                _ = self.words.swapRemove(idx);
            } else {
                idx += 1;
            }
        }
    }
}
