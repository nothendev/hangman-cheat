const std = @import("std");

pub const utf8 = struct {
    pub fn toLower(cp: u21) u21 {
        return switch (cp) {
            'A'...'Z' => cp + 'a' - 'A',
            'À'...'Ö' => cp + 'a' - 'A',
            else => cp,
        };
    }
};

test "toLower" {
    try std.testing.expectEqual(@as(u21, 'á'), utf8.toLower('Á'));
    try std.testing.expectEqual(@as(u21, 'ß'), utf8.toLower('ß'));
    try std.testing.expectEqual(@as(u21, 'z'), utf8.toLower('Z'));
}
