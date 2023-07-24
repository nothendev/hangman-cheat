const std = @import("std");
const unicode = std.unicode;
const ascii = std.ascii;
const math = std.math;
const mem = std.mem;
const fs = std.fs;
const os = std.os;

const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

const next_pane = "\n" ++ "-" ** 50 ++ "\n\n";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var files = std.ArrayList([]const u8).init(allocator);
    defer files.deinit();
    var dir = try fs.cwd().openDir("./resources", .{});
    defer dir.close();

    var resource_dir = try fs.cwd().openIterableDir("./resources", .{});
    defer resource_dir.close();
    var res_iter = resource_dir.iterate();
    while (try res_iter.next()) |ifile| {
        if (ifile.kind != .file) {
            continue;
        }
        const file = try dir.openFile(ifile.name, .{});
        defer file.close();
        const file_contents = try file.readToEndAlloc(allocator, math.maxInt(usize));
        try files.append(file_contents);
        try stdout.print("[SYSTEM] Loaded {s: >32}\n", .{ifile.name});
    }
    if (files.items.len == 0) {
        try stdout.print("[ERROR] No files found", .{});
        return;
    }

    defer for (files.items) |file|
        allocator.free(file);
    try stdout.print(next_pane, .{});

    try stdout.print("Please enter the length of the word: ", .{});
    const len = len: {
        const in = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 4);
        break :len std.fmt.parseInt(u8, in.?, 10) catch |err| switch (err) {
            error.InvalidCharacter => {
                try stdout.print("I asked for a number.\n", .{});
                os.exit(1);
            },
            error.Overflow => {
                try stdout.print("I highly doubt that word has more than {d} letters...\n", .{math.maxInt(u8)});
                os.exit(1);
            },
        };
    };
    try stdout.print("Okidoki!\n", .{});

    var reqs = try Requirements.init(allocator, len);
    defer reqs.info.deinit();

    var words = Words.init(allocator);
    defer words.deinit();
    for (files.items) |file| {
        try words.addFile(file);
    }

    outer: while (reqs.validChars() < reqs.len) {
        words = try words.withRequirements(allocator, reqs);
        if (words.words.items.len <= 1) {
            break :outer;
        }
        try stdout.print(next_pane, .{});
        const current_word = try reqs.toWord(allocator);
        defer allocator.free(current_word);
        try stdout.print("Current word: {s}\n", .{current_word});
        try stdout.print("{d} words match your requirements.\n", .{words.words.items.len});
        if (words.words.items.len <= 10) {
            for (0..@min(words.words.items.len, 9)) |i| {
                try stdout.print("\t{s}\n", .{words.words.items[i]});
            }
        }
        const common_char = words.mostCommonChar(reqs);
        try stdout.print("The most common character is '{c}'.\n", .{common_char});

        try stdout.print("It matched for the spots: ", .{});
        const in = in: {
            const in = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', math.maxInt(usize));
            if (in.?.len < 1) {
                try reqs.info.append(Char{ .char = common_char, .pos = null });
                continue :outer;
            }
            for (in.?) |char| {
                switch (char) {
                    '0'...'9', ',' => {},
                    else => {
                        try stdout.print("'{s}' contains invalid characters.\n", .{in.?});
                        continue :outer;
                    },
                }
            }
            break :in in.?;
        };
        defer allocator.free(in);

        var iter = mem.splitSequence(u8, in, ",");
        while (iter.next()) |num_str| {
            const num = std.fmt.parseInt(u8, num_str, 10) catch |err| switch (err) {
                error.Overflow => {
                    try stdout.print(
                        "I highly doubt that word has more than {d} letters...\n",
                        .{math.maxInt(u8)},
                    );
                    continue :outer;
                },
                else => return err,
            };
            try reqs.append(common_char, num - 1);
        }
    }
    try stdout.print(next_pane, .{});
    words = try words.withRequirements(allocator, reqs);
    if (words.words.items.len > 0) {
        try stdout.print("You won! The word was: '{s}' (Right?)\n", .{words.words.items[0]});
    } else {
        try stdout.print("No words in the database match.\n", .{});
    }
}

const Char = struct {
    char: u8,
    pos: ?u8,
};

const Requirements = struct {
    len: u8,
    info: std.ArrayList(Char),

    pub fn init(allocator: Allocator, len: u8) !Requirements {
        return Requirements{
            .len = len,
            .info = std.ArrayList(Char).init(allocator),
        };
    }

    pub fn deinit(self: Requirements) void {
        self.info.deinit();
    }

    /// caller owns returned memory
    pub fn toWord(self: Requirements, allocator: Allocator) ![]const u8 {
        const word = try allocator.alloc(u8, self.len);
        @memset(word, '_');
        for (self.info.items) |info| {
            word[info.pos orelse continue] = info.char;
        }
        return word;
    }

    pub fn containsInfoOn(self: Requirements, char: u8) bool {
        for (self.info.items) |c| {
            if (char == c.char) {
                return true;
            }
        }
        return false;
    }

    pub fn append(self: *Requirements, char: u8, pos: ?u8) !void {
        for (self.info.items) |info| {
            if (info.pos == pos) {
                return error.CharacterAlreadyKnown;
            }
        }
        try self.info.append(Char{ .pos = pos, .char = char });
    }

    pub fn validChars(self: Requirements) u8 {
        var n: u8 = 0;
        for (self.info.items) |char| {
            if (char.pos) |_|
                n += 1;
        }
        return n;
    }
};

const Words = struct {
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

    pub fn mostCommonChar(self: Words, reqs: Requirements) u8 {
        var chars = [_]usize{0} ** math.maxInt(u8);
        for (self.words.items) |word| {
            for (word) |char| {
                if (!ascii.isAlphabetic(char) or reqs.containsInfoOn(ascii.toLower(char))) {
                    continue;
                }
                chars[ascii.toLower(char)] += 1;
            }
        }
        var char: u8 = 0;
        var most_common: usize = 0;
        for (chars, 0..) |n, i| {
            if (n > most_common)
                char = @intCast(i);
            most_common = @max(n, most_common);
        }
        if (char == 0)
            @panic("returned character is the null character");
        if (!(ascii.isAlphabetic(char) or char == '-'))
            @panic("returned character is not valid");
        return ascii.toLower(char);
    }

    pub fn withRequirements(
        self: Words,
        allocator: Allocator,
        reqs: Requirements,
    ) !Words {
        var new_words = Words.init(allocator);
        word_loop: for (self.words.items) |word| {
            // if (try unicode.calcUtf16LeLen(word) != reqs.len)
            if (word.len != reqs.len) {
                continue :word_loop;
            }

            for (reqs.info.items) |info| {
                var buf = [_]bool{true} ** math.maxInt(u8);
                var checklist = buf[0..reqs.len];

                for (reqs.info.items) |_info| {
                    if (info.char == _info.char and _info.pos != null) {
                        checklist[_info.pos.?] = false;
                    }
                }

                for (word, checklist) |char, check| {
                    if ((info.char == ascii.toLower(char)) == check) {
                        continue :word_loop;
                    }
                }
            }

            try new_words.words.append(word);
        }

        return new_words;
    }
};
