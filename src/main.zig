const std = @import("std");
const ranges = @import("ranges");

fn isEven(x: usize) bool {
    return x % 2 == 0;
}

fn square(x: usize) usize {
    return x * x;
}

fn lessThen(x: usize) bool {
    return x > 1000;
}

pub fn main() void {
    const range = ranges.Range(usize).init(0, 100);
    var it = range
        .filter(isEven)
        .map(square)
        .filter(lessThen);

    const numOpt = it.find(1296);
    if (numOpt) |num| {
        std.debug.print("Found: {}\n", .{num});
    } else {
        std.debug.print("Not found \n", .{});
    }

    std.debug.print("Type of it: {s}\n", .{@typeName(@TypeOf(it))});
}
