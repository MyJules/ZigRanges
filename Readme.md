# ZigRanges

A lightweight, composable iterator library for Zig that brings functional programming patterns to range iteration.

## Features

- **Lazy Evaluation**: Iterators are evaluated on-demand
- **Method Chaining**: Compose operations with `.map()`, `.filter()`, `.sorted()`, and more
- **Custom Type Support**: Sort and compare custom structs with ease
- **Generic Types**: Works with any type using Zig's compile-time generics
- **Zero Dependencies**: Uses only Zig's standard library

## Installation

### Using Zig Package Manager (Recommended)

1. **Add ZigRanges to your `build.zig.zon`:**
   ```zig
   .{
       .name = "your-app",
       .version = "0.1.0",
       .dependencies = .{
           .ranges = .{
               .url = "https://github.com/yourusername/ZigRanges/archive/refs/tags/v0.1.0.tar.gz",
               .hash = "1220...", // zig will tell you the correct hash
           },
       },
   }
   ```

2. **Update your `build.zig`:**
   ```zig
   const std = @import("std");

   pub fn build(b: *std.Build) void {
       const target = b.standardTargetOptions(.{});
       const optimize = b.standardOptimizeOption(.{});

       // Import ranges as a dependency
       const ranges = b.dependency("ranges", .{
           .target = target,
           .optimize = optimize,
       }).module("ranges");

       const exe = b.addExecutable(.{
           .name = "your-app",
           .root_source_file = b.path("src/main.zig"),
           .target = target,
           .optimize = optimize,
       });

       // Add ranges module
       exe.root_module.addImport("ranges", ranges);

       b.installArtifact(exe);
   }
   ```

3. **Use in your code:**
   ```zig
   const ranges = @import("ranges");
   
   pub fn main() !void {
       var result = try ranges.Range(i32).init(0, 10)
           .filter(isEven)
           .map(square)
           .collect(allocator);
       defer result.deinit(allocator);
   }
   ```

### Alternative: Local Path (Development)

If you're developing locally or using a git submodule:

1. **Add to your `build.zig.zon`:**
   ```zig
   .dependencies = .{
       .ranges = .{
           .path = "libs/ZigRanges",
       },
   },
   ```

2. **Use the same `build.zig` setup as above**

### Alternative: Git Submodule (Legacy)

```bash
git submodule add https://github.com/yourusername/ZigRanges libs/ZigRanges
```

Then use the local path method in your `build.zig.zon`.

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

    if (it.find(1)) |found| {
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
    return x < 20;
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

### Custom Struct

```zig
const std = @import("std");
const ranges = @import("ranges");

const MyStruct = struct {
    value: i32,
};

fn squareStruct(s: MyStruct) MyStruct {
    return MyStruct{
        .value = s.value * s.value,
    };
}

fn isEvenStruct(s: MyStruct) bool {
    return @mod(s.value, 2) == 0;
}

pub fn main() void {
    const array = [_]MyStruct{
        .{ .value = 1 },
        .{ .value = 2 },
        .{ .value = 3 },
        .{ .value = 4 },
    };
    const arrayRange = ranges.ArrayRange(MyStruct).init(&array);
    var it = arrayRange
        .map(squareStruct)
        .filter(isEvenStruct);

    while (it.next()) |v| {
        std.debug.print("Squared struct value: {}\n", .{v});
    }
}
```


### Custom Struct

```zig
const std = @import("std");
const ranges = @import("ranges");

fn toUpperCase(c: u8) u8 {
    if (c >= 'a' and c <= 'z') {
        return c - 32;
    }
    return c;
}

pub fn main() !void {
    const string = "Hello, Zig Ranges!";

    const range = ranges.ArrayRange(u8).init(string);
    var it = range
        .map(toUpperCase);

    while (it.next()) |c| {
        std.debug.print("{c}", .{c});
    }

    std.debug.print("\n", .{});

    std.debug.print("{s} \n", .{string});
}

```

### Sorting

```zig
const std = @import("std");
const ranges = @import("ranges");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Sort integers
    const array = [_]i32{ 5, 2, 8, 1, 9, 3 };
    var sorted = try ranges.ArrayRange(i32).init(&array)
        .sorted(allocator);
    defer sorted.deinit(allocator);
    
    std.debug.print("Sorted: {any}\n", .{sorted.items});
    // Output: Sorted: [1, 2, 3, 5, 8, 9]
}
```

### Custom Type Sorting

```zig
const std = @import("std");
const ranges = @import("ranges");

const Person = struct {
    name: []const u8,
    age: u32,
    
    fn compareByAge(a: Person, b: Person) bool {
        return a.age < b.age;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const people = [_]Person{
        .{ .name = "Alice", .age = 30 },
        .{ .name = "Bob", .age = 25 },
        .{ .name = "Charlie", .age = 35 },
    };
    
    var sorted = try ranges.ArrayRange(Person).init(&people)
        .sortedBy(allocator, Person.compareByAge);
    defer sorted.deinit(allocator);
    
    for (sorted.items) |p| {
        std.debug.print("{s}: {}\n", .{ p.name, p.age });
    }
    // Output: Bob: 25, Alice: 30, Charlie: 35
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