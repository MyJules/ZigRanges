const std = @import("std");
const ranges = @import("ranges.zig");

fn isEven1(x: i32) bool {
    return @mod(x, 2) == 0;
}

fn square1(x: i32) i32 {
    return x * x;
}

fn squareMyType(x: MyType) MyType {
    return MyType{ .lol = x.lol * x.lol };
}

fn isEven(x: usize) bool {
    return x % 2 == 0;
}

fn square(x: usize) usize {
    return x * x;
}

fn lessThen(x: usize) bool {
    return x > 1000;
}

const MyType = struct {
    lol: i32,
};

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

    std.debug.print("Range: \n", .{});
    while (it.next()) |v| {
        std.debug.print("{d} ", .{v});
    }

    std.debug.print("\n", .{});
    std.debug.print("````````````````", .{});
    std.debug.print("\n", .{});

    const array = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const arrayRange = ranges.ArrayRange(i32).init(&array);
    var it1 = arrayRange
        .map(square1);

    std.debug.print("Type of it1: {s}\n", .{@typeName(@TypeOf(it1))});

    std.debug.print("ArrayRange: \n", .{});
    while (it1.next()) |v| {
        std.debug.print("{d} ", .{v});
    }

    std.debug.print("\n", .{});
    std.debug.print("````````````````", .{});
    std.debug.print("\n", .{});

    for (array, 0..) |value, idx| {
        std.debug.print("arr[{}] = {}\n", .{ idx, value });
    }

    std.debug.print("\n", .{});
    std.debug.print("````````````````", .{});
    std.debug.print("\n", .{});

    const myTypeArray = [_]MyType{ MyType{ .lol = 2 }, MyType{ .lol = 4 } };
    const arrayRange1 = ranges.ArrayRange(MyType).init(&myTypeArray);
    var it2 = arrayRange1
        .map(squareMyType);

    const value2 = it2.find(MyType{ .lol = 16 });
    if (value2) |value| {
        std.debug.print("Found: {}\n", .{value.lol});
    } else {
        std.debug.print("Not found \n", .{});
    }

    while (it2.next()) |v| {
        std.debug.print("{d} ", .{v.lol});
    }
}
