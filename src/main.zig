const std = @import("std");
const unicode = std.unicode;
const ascii = std.ascii;
const math = std.math;
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const io = std.io;
const util = @import("util.zig");

const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const assert = std.debug.assert;

const Words = @import("Words.zig");
const Requirements = @import("Requirements.zig");

const next_pane = "\n" ++ "-" ** 50 ++ "\n\n";
const resource_path = "./resources";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var files = std.ArrayList([]const u8).init(allocator);
    defer files.deinit();

    var dir = try fs.cwd().openDir(resource_path, .{});
    defer dir.close();

    var resource_dir = try fs.cwd().openIterableDir(resource_path, .{});
    defer resource_dir.close();
    var resource_iter = resource_dir.iterate();
    while (try resource_iter.next()) |ifile| {
        if (ifile.kind != .file) {
            continue;
        }

        const file = try dir.openFile(ifile.name, .{});
        defer file.close();

        const file_contents = try file.readToEndAlloc(allocator, math.maxInt(usize));
        errdefer allocator.free(file_contents);
        try files.append(file_contents);

        try stdout.print("[SYSTEM] Loaded {s: >32}\n", .{ifile.name});
    }
    defer for (files.items) |file| {
        allocator.free(file);
    };

    if (files.items.len == 0) {
        try stdout.print("[ERROR] No files found", .{});
        os.exit(1);
    }

    try stdout.print(next_pane, .{});

    const len = len: while (true) {
        try stdout.print("Please enter the length of the word: ", .{});

        const in = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 4);
        defer allocator.free(in.?);

        break :len std.fmt.parseInt(usize, in.?, 10) catch |err| switch (err) {
            error.InvalidCharacter => {
                try stdout.print("[ERROR] not a number\n", .{});
                continue;
            },
            error.Overflow => {
                try stdout.print("[ERROR] integer overflow\n", .{});
                continue;
            },
        };
    };

    var reqs = try Requirements.init(allocator, len);
    defer reqs.info.deinit();

    var words = Words.init(allocator);
    defer words.deinit();
    for (files.items) |file| {
        try words.addFile(file);
    }
    try stdout.print("[SYSTEM] {d} words loaded\n", .{words.words.items.len});

    iteration: while (reqs.validChars() < reqs.len) {
        try words.removeUnsuitable(reqs);
        if (words.words.items.len <= 1) {
            break :iteration;
        }

        try stdout.print(next_pane, .{});

        try stdout.print("{d} words match your requirements.\n", .{words.words.items.len});
        if (words.words.items.len <= 10) {
            for (words.words.items) |word| {
                try stdout.print("\t- {s}\n", .{word});
            }
        }

        const current_word = try reqs.toWord(allocator);
        defer allocator.free(current_word);
        try stdout.print("Current word: {u}\n", .{current_word});

        const common_char = try words.mostCommonChar(reqs);
        try stdout.print("The most common character is '{u}'.\n", .{common_char});

        const in = in: {
            try stdout.print("It matched for the spots: ", .{});

            const in = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', math.maxInt(usize));
            if (in.?.len < 1) {
                try reqs.info.append(Requirements.Char{ .char = common_char, .pos = null });
                continue :iteration;
            }

            for (in.?) |char| {
                switch (char) {
                    '0'...'9', ',' => {},
                    else => {
                        try stdout.print("[ERROR] contains invalid characters\n", .{});
                        continue;
                    },
                }
            }

            break :in in.?;
        };
        defer allocator.free(in);

        var iter = mem.splitSequence(u8, in, ",");
        while (iter.next()) |num_str| {
            const num = std.fmt.parseInt(usize, num_str, 10) catch |err| switch (err) {
                error.Overflow => {
                    try stdout.print("[ERROR] integer overflow\n", .{});
                    continue :iteration;
                },
                else => return err,
            };
            try reqs.append(common_char, num - 1);
        }
    }

    try stdout.print(next_pane, .{});

    try words.removeUnsuitable(reqs);

    if (words.words.items.len > 0) {
        try stdout.print("You won! The word was: '{s}' (Right?)\n", .{words.words.items[0]});
    } else {
        try stdout.print("No words in the database match.\n", .{});
    }

    // try stdout.print("made by markus_or_smth\n", .{});
}
