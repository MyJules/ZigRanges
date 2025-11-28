# ZigRanges

A lightweight, composable iterator library for Zig that brings functional programming patterns to range iteration.

## Features

- **Lazy Evaluation**: Iterators are evaluated on-demand
- **Method Chaining**: Compose operations with `.map()`, `.filter()`, `.find()`, and `.collect()`
- **Generic Types**: Works with any type using Zig's compile-time generics
- **Zero Dependencies**: Uses only Zig's standard library

## Quick Start

### Basic Range Iteration

```zig
const std = @import("std");
const ranges = @import("ranges");

pub fn main() void {
    const range = ranges.Range(usize).init(0, 10);
    var it = range;

    while (it.next()) |value| {
        std.debug.print("{} ", .{value});
    }
    // Output: 0 1 2 3 4 5 6 7 8 9
}
```

### Filtering and Mapping

```zig
const std = @import("std");
const ranges = @import("ranges");

fn isEven(x: usize) bool {
    return x % 2 == 0;
}

fn square(x: usize) usize {
    return x * x;
}

pub fn main() void {
    const range = ranges.Range(usize).init(0, 10);
    var it = range
        .filter(isEven)
        .map(square);

    while (it.next()) |value| {
        std.debug.print("{} ", .{value});
    }
    // Output: 0 4 16 36 64
}
```

### Array
```zig
const std = @import("std");
const ranges = @import("ranges");

fn isEven(x: usize) bool {
    return x % 2 == 0;
}

fn square(x: usize) usize {
    return x * x;
}

pub fn main() void {
    const array = [_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    const arrayRange = ranges.ArrayRange(usize).init(&array);
    var it = arrayRange
        .filter(isEven)
        .map(square);

    while (it.next()) |value| {
        std.debug.print("{} ", .{value});
    }
    // Output: 0 4 16 36 64
}
```

### Finding Elements

```zig
const std = @import("std");
const ranges = @import("ranges");

fn isEven(x: usize) bool {
    return x % 2 == 0;
}

fn square(x: usize) usize {
    return x * x;
}

pub fn main() void {
    const range = ranges.Range(usize).init(0, 100);
    var it = range
        .filter(isEven)
        .map(square);

    if (it.find(1296)) |found| {
        std.debug.print("Found: {}\n", .{found});
    } else {
        std.debug.print("Not found\n", .{});
    }
}
```

### Collecting Results

```zig
const std = @import("std");
const ranges = @import("ranges");

fn isEven(x: usize) bool {
    return x % 2 == 0;
}

fn square(x: usize) usize {
    return x * x;
}

fn lessThen(x: usize) bool {
    return x > 8;
}

pub fn main() !void {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocator.deinit();

    const gp_allocator = allocator.allocator();

    const array = [_]usize{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const range = ranges.ArrayRange(usize).init(&array);
    var it = range
        .filter(isEven)
        .map(square)
        .filter(lessThen);

    var collected = try it.collect(gp_allocator);
    defer collected.deinit(gp_allocator);

    std.debug.print("Collected: {any}\n", .{collected.items});

    std.debug.print("Type of it: {s}\n", .{@typeName(@TypeOf(it))});
}
```

## API Reference

### `Range(T)`

Creates a numeric range iterator.

**Methods:**
- `init(start: usize, end: usize)` - Create a range from start (inclusive) to end (exclusive)
- `next()` - Get the next value, returns `?T`
- `map(comptime F)` - Transform each element
- `filter(comptime P)` - Keep only elements matching a predicate
- `find(value: T)` - Find a specific value, returns `?T`
- `collect(allocator)` - Collect all elements into an `ArrayList(T)`

### `ArrayRange(T)`

Creates an iterator over array elements.

**Methods:**
- `init(arr: []const T)` - Create an iterator from a slice
- `next()` - Get the next value, returns `?T`
- `map(comptime F)` - Transform each element
- `filter(comptime P)` - Keep only elements matching a predicate
- `find(value: T)` - Find a specific value, returns `?T`
- `collect(allocator)` - Collect all elements into an `ArrayList(T)`

## Building

```bash
# Build the project
zig build

# Run the example
zig build run

# Run tests
zig test ranges_test.zig
```

## Testing

The library includes comprehensive tests. Run them with:

```bash
zig test ranges_test.zig
```

Test coverage includes:
- Range iteration with filtering and mapping
- Array range operations
- Finding elements in chains
- Collecting results into `ArrayList`
- Custom type support

## Requirements

- Zig 0.11.0 or later

## License

This project is open source.

## Examples

See `src/main.zig` for a complete working example and `src/ranges_test.zig` for more usage patterns.