const std = @import("std");
const ranges = @import("ranges");

// Example 1: Helper functions for basic operations
fn isEven(x: i32) bool {
    return @mod(x, 2) == 0;
}

fn isOdd(x: i32) bool {
    return @mod(x, 2) != 0;
}

fn square(x: i32) i32 {
    return x * x;
}

fn double(x: i32) i32 {
    return x * 2;
}

fn add(acc: i32, x: i32) i32 {
    return acc + x;
}

fn multiply(acc: i32, x: i32) i32 {
    return acc * x;
}

// Example 2: Custom struct with methods
const Person = struct {
    name: []const u8,
    age: u32,
    city: []const u8,

    fn compareByAge(a: Person, b: Person) bool {
        return a.age < b.age;
    }

    fn compareByName(a: Person, b: Person) bool {
        return std.mem.order(u8, a.name, b.name) == .lt;
    }

    fn isAdult(p: Person) bool {
        return p.age >= 18;
    }

    fn format(self: Person, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s} ({}, {s})", .{ self.name, self.age, self.city });
    }
};

// Example 3: Point struct for geometric operations
const Point = struct {
    x: i32,
    y: i32,

    fn distanceFromOrigin(self: Point) i32 {
        return self.x * self.x + self.y * self.y;
    }

    fn compareByDistance(a: Point, b: Point) bool {
        return a.distanceFromOrigin() < b.distanceFromOrigin();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== ZigRanges Library Examples ===\n\n", .{});

    // Example 1: Basic Range with Filter and Map
    try example1_BasicFilterMap();

    // Example 2: Array Range Operations
    try example2_ArrayRange(allocator);

    // Example 3: Collecting Results
    try example3_Collecting(allocator);

    // Example 4: Sorting Primitives
    try example4_SortingPrimitives(allocator);

    // Example 5: Custom Type Sorting
    try example5_CustomTypeSorting(allocator);

    // Example 6: Complex Chains
    try example6_ComplexChains(allocator);

    // Example 7: Fold Operations
    try example7_FoldOperations();

    // Example 8: Any and All
    try example8_AnyAndAll();

    // Example 9: Count and Find
    try example9_CountAndFind();

    // Example 10: Working with ArrayList
    try example10_ArrayList(allocator);

    std.debug.print("\n=== All Examples Completed Successfully! ===\n", .{});
}

fn example1_BasicFilterMap() !void {
    std.debug.print("Example 1: Basic Range with Filter and Map\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    var iter = ranges.Range(i32).init(0, 10)
        .filter(isEven)
        .map(square);

    std.debug.print("Range(0, 10).filter(isEven).map(square):\n", .{});
    std.debug.print("Result: ", .{});
    while (iter.next()) |value| {
        std.debug.print("{} ", .{value});
    }
    std.debug.print("\n\n", .{});
}

fn example2_ArrayRange(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 2: Array Range Operations\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    const array = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    var result = try ranges.ArrayRange(i32).init(&array)
        .filter(isOdd)
        .map(double)
        .collect(allocator);
    defer result.deinit(allocator);

    std.debug.print("Array: {any}\n", .{array});
    std.debug.print("After filter(isOdd).map(double): {any}\n\n", .{result.items});
}

fn example3_Collecting(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 3: Collecting Results\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    // Collect into ArrayList
    var list = try ranges.Range(i32).init(1, 6)
        .map(square)
        .collect(allocator);
    defer list.deinit(allocator);
    std.debug.print("collect() -> ArrayList: {any}\n", .{list.items});

    // Collect into slice
    const slice = try ranges.Range(i32).init(1, 6)
        .map(square)
        .collectSlice(allocator);
    defer allocator.free(slice);
    std.debug.print("collectSlice() -> []T: {any}\n", .{slice});

    // Collect into fixed array
    const array = try ranges.Range(i32).init(1, 6)
        .map(square)
        .collectArray(5);
    std.debug.print("collectArray(5) -> [5]T: {any}\n\n", .{array});
}

fn example4_SortingPrimitives(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 4: Sorting Primitives\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    const unsorted = [_]i32{ 5, 2, 8, 1, 9, 3, 7, 4, 6 };

    var sorted = try ranges.ArrayRange(i32).init(&unsorted)
        .sorted(allocator);
    defer sorted.deinit(allocator);

    std.debug.print("Original: {any}\n", .{unsorted});
    std.debug.print("Sorted:   {any}\n\n", .{sorted.items});

    // Sort with filter first
    var filtered_sorted = try ranges.ArrayRange(i32).init(&unsorted)
        .filter(isEven)
        .sorted(allocator);
    defer filtered_sorted.deinit(allocator);

    std.debug.print("Evens only, sorted: {any}\n\n", .{filtered_sorted.items});
}

fn example5_CustomTypeSorting(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 5: Custom Type Sorting\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    const people = [_]Person{
        .{ .name = "Alice", .age = 30, .city = "New York" },
        .{ .name = "Bob", .age = 25, .city = "London" },
        .{ .name = "Charlie", .age = 35, .city = "Tokyo" },
        .{ .name = "Diana", .age = 28, .city = "Paris" },
    };

    // Sort by age
    var by_age = try ranges.ArrayRange(Person).init(&people)
        .sortedBy(allocator, Person.compareByAge);
    defer by_age.deinit(allocator);

    std.debug.print("Sorted by age:\n", .{});
    for (by_age.items) |p| {
        std.debug.print("  {}\n", .{p});
    }

    // Sort by name
    var by_name = try ranges.ArrayRange(Person).init(&people)
        .sortedBy(allocator, Person.compareByName);
    defer by_name.deinit(allocator);

    std.debug.print("\nSorted by name:\n", .{});
    for (by_name.items) |p| {
        std.debug.print("  {}\n", .{p});
    }
    std.debug.print("\n", .{});
}

fn example6_ComplexChains(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 6: Complex Operation Chains\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    // Chain: range -> filter odds -> square -> keep < 100 -> sort
    var result = try ranges.Range(i32).init(1, 20)
        .filter(isOdd)
        .map(square)
        .filter(struct {
            fn lessThan100(x: i32) bool {
                return x < 100;
            }
        }.lessThan100)
        .sorted(allocator);
    defer result.deinit(allocator);

    std.debug.print("Range(1,20) -> odds -> square -> <100 -> sort:\n", .{});
    std.debug.print("{any}\n\n", .{result.items});

    // Filter adults and sort by age
    const people = [_]Person{
        .{ .name = "Alice", .age = 30, .city = "NYC" },
        .{ .name = "Bob", .age = 17, .city = "LA" },
        .{ .name = "Charlie", .age = 35, .city = "SF" },
        .{ .name = "Diana", .age = 16, .city = "Seattle" },
        .{ .name = "Eve", .age = 22, .city = "Boston" },
    };

    var adults = try ranges.ArrayRange(Person).init(&people)
        .filter(Person.isAdult)
        .sortedBy(allocator, Person.compareByAge);
    defer adults.deinit(allocator);

    std.debug.print("Adults only, sorted by age:\n", .{});
    for (adults.items) |p| {
        std.debug.print("  {}\n", .{p});
    }
    std.debug.print("\n", .{});
}

fn example7_FoldOperations() !void {
    std.debug.print("Example 7: Fold Operations\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    // Sum
    const sum = ranges.Range(i32).init(1, 11)
        .fold(add, @as(i32, 0));
    std.debug.print("Sum of 1..10: {}\n", .{sum});

    // Product
    const product = ranges.Range(i32).init(1, 6)
        .fold(multiply, @as(i32, 1));
    std.debug.print("Product of 1..5 (factorial): {}\n", .{product});

    // Sum of squares
    const sum_of_squares = ranges.Range(i32).init(1, 6)
        .map(square)
        .fold(add, @as(i32, 0));
    std.debug.print("Sum of squares 1..5: {}\n\n", .{sum_of_squares});
}

fn example8_AnyAndAll() !void {
    std.debug.print("Example 8: Any and All Predicates\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    const hasNegative = ranges.Range(i32).init(-5, 5)
        .any(struct {
        fn isNegative(x: i32) bool {
            return x < 0;
        }
    }.isNegative);
    std.debug.print("Range(-5, 5) has negative? {}\n", .{hasNegative});

    const allPositive = ranges.Range(i32).init(1, 10)
        .all(struct {
        fn isPositive(x: i32) bool {
            return x > 0;
        }
    }.isPositive);
    std.debug.print("Range(1, 10) all positive? {}\n", .{allPositive});

    const allEven = ranges.Range(i32).init(2, 11)
        .filter(isEven)
        .all(isEven);
    std.debug.print("Filtered evens all even? {}\n\n", .{allEven});
}

fn example9_CountAndFind() !void {
    std.debug.print("Example 9: Count and Find\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    // Count
    const evenCount = ranges.Range(i32).init(0, 20)
        .filter(isEven)
        .count();
    std.debug.print("Number of evens in 0..20: {}\n", .{evenCount});

    // Find
    var iter = ranges.Range(i32).init(0, 100)
        .filter(isEven)
        .map(square);

    if (iter.find(1600)) |found| {
        std.debug.print("Found value: {}\n", .{found});
    } else {
        std.debug.print("Value not found\n", .{});
    }

    // Find in custom structs
    const points = [_]Point{
        .{ .x = 3, .y = 4 },
        .{ .x = 1, .y = 1 },
        .{ .x = 5, .y = 0 },
    };

    const target = Point{ .x = 1, .y = 1 };
    var point_iter = ranges.ArrayRange(Point).init(&points);
    if (point_iter.find(target)) |found| {
        std.debug.print("Found point: ({}, {})\n", .{ found.x, found.y });
    }
    std.debug.print("\n", .{});
}

fn example10_ArrayList(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 10: Working with ArrayList\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    var list = try std.ArrayList(i32).initCapacity(allocator, 10);
    defer list.deinit(allocator);

    try list.append(allocator, 5);
    try list.append(allocator, 2);
    try list.append(allocator, 8);
    try list.append(allocator, 1);
    try list.append(allocator, 9);
    try list.append(allocator, 3);

    std.debug.print("ArrayList contents: {any}\n", .{list.items});

    // Use ranges on ArrayList.items
    var sorted = try ranges.ArrayRange(i32).init(list.items)
        .sorted(allocator);
    defer sorted.deinit(allocator);

    std.debug.print("Sorted: {any}\n", .{sorted.items});

    // Filter and transform
    var processed = try ranges.ArrayRange(i32).init(list.items)
        .filter(isEven)
        .map(square)
        .collect(allocator);
    defer processed.deinit(allocator);

    std.debug.print("Evens squared: {any}\n", .{processed.items});
}
