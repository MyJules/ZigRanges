const std = @import("std");
const ranges = @import("ranges");

pub fn main() !void {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocator.deinit();

    const gp_allocator = allocator.allocator();

    const range = ranges.Range(usize).init(0, 100);
    var it = range
    .filter(struct {
            fn isEven(x: usize) bool {
                return x % 2 == 0;
            }
        }.isEven)
    .map(struct {
            fn square(x: usize) usize {
                return x * x;
            }
        }.square)
    .filter(struct {
            fn isLessThan(x: usize) bool {
                return x < 1000;
            }
        }.isLessThan);

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
