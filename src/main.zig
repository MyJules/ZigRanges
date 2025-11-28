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

pub fn main() !void {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocator.deinit();

    const gp_allocator = allocator.allocator();

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

    var collected = try it.collect(gp_allocator);
    defer collected.deinit(gp_allocator);

    std.debug.print("Collected: {any}\n", .{collected.items});

    std.debug.print("Type of it: {s}\n", .{@typeName(@TypeOf(it))});
}
