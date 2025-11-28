const std = @import("std");
const ranges = @import("ranges.zig");

fn isEven(x: usize) bool { return x % 2 == 0; }
fn square(x: usize) usize { return x * x; }

pub fn main() void {
    var range = ranges.range(0, 20);

    var it = range
        .filter(isEven)
        .map(square);

    while (it.next()) |v| {
        std.debug.print("{d}\n", .{v});
    }
}

