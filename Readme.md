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

### Fold Operations (Reduce)

```zig
const std = @import("std");
const ranges = @import("ranges");

fn add(acc: i32, x: i32) i32 {
    return acc + x;
}

fn multiply(acc: i32, x: i32) i32 {
    return acc * x;
}

pub fn main() void {
    // Sum of numbers 1 to 10
    const sum = ranges.Range(i32).init(1, 11)
        .fold(0, add);
    std.debug.print("Sum: {}\n", .{sum});
    // Output: Sum: 55
    
    // Product (factorial of 5)
    const product = ranges.Range(i32).init(1, 6)
        .fold(1, multiply);
    std.debug.print("Product: {}\n", .{product});
    // Output: Product: 120
    
    // Sum of squares
    const sumOfSquares = ranges.Range(i32).init(1, 6)
        .map(square)
        .fold(0, add);
    std.debug.print("Sum of squares: {}\n", .{sumOfSquares});
    // Output: Sum of squares: 55
}

fn square(x: i32) i32 {
    return x * x;
}
```

### Any and All Predicates

```zig
const std = @import("std");
const ranges = @import("ranges");

fn isNegative(x: i32) bool {
    return x < 0;
}

fn isPositive(x: i32) bool {
    return x > 0;
}

fn isEven(x: i32) bool {
    return @mod(x, 2) == 0;
}

pub fn main() void {
    // Check if any element is negative
    const hasNegative = ranges.Range(i32).init(-5, 5)
        .any(isNegative);
    std.debug.print("Has negative? {}\n", .{hasNegative});
    // Output: Has negative? true
    
    // Check if all elements are positive
    const allPositive = ranges.Range(i32).init(1, 10)
        .all(isPositive);
    std.debug.print("All positive? {}\n", .{allPositive});
    // Output: All positive? true
    
    // Check filtered range
    const allEven = ranges.Range(i32).init(0, 20)
        .filter(isEven)
        .all(isEven);
    std.debug.print("All even? {}\n", .{allEven});
    // Output: All even? true
}
```

### Count and Find Operations

```zig
const std = @import("std");
const ranges = @import("ranges");

fn isEven(x: i32) bool {
    return @mod(x, 2) == 0;
}

fn square(x: i32) i32 {
    return x * x;
}

pub fn main() void {
    // Count even numbers
    const evenCount = ranges.Range(i32).init(0, 21)
        .filter(isEven)
        .count();
    std.debug.print("Number of evens: {}\n", .{evenCount});
    // Output: Number of evens: 10
    
    // Find a specific value in transformed range
    const found = ranges.Range(i32).init(1, 100)
        .map(square)
        .find(1600);
    
    if (found) |value| {
        std.debug.print("Found: {}\n", .{value});
        // Output: Found: 1600
    }
}
```

### Complex Operation Chains

```zig
const std = @import("std");
const ranges = @import("ranges");

fn isOdd(x: i32) bool {
    return @mod(x, 2) != 0;
}

fn square(x: i32) i32 {
    return x * x;
}

fn lessThan100(x: i32) bool {
    return x < 100;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Chain multiple operations: filter odds, square them, 
    // keep only those < 100, then sort
    var result = try ranges.Range(i32).init(1, 20)
        .filter(isOdd)
        .map(square)
        .filter(lessThan100)
        .sorted(allocator);
    defer result.deinit(allocator);
    
    std.debug.print("Result: {any}\n", .{result.items});
    // Output: Result: [1, 9, 25, 49, 81]
}
```

### Working with ArrayList

```zig
const std = @import("std");
const ranges = @import("ranges");

fn isEven(x: i32) bool {
    return @mod(x, 2) == 0;
}

fn square(x: i32) i32 {
    return x * x;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create ArrayList
    var list = std.ArrayList(i32).init(allocator);
    defer list.deinit();
    
    try list.append(allocator, 5);
    try list.append(allocator, 2);
    try list.append(allocator, 8);
    try list.append(allocator, 1);
    
    // Sort the ArrayList items using ranges
    var sorted = try ranges.ArrayRange(i32).init(list.items)
        .sorted(allocator);
    defer sorted.deinit(allocator);
    
    std.debug.print("Original: {any}\n", .{list.items});
    std.debug.print("Sorted: {any}\n", .{sorted.items});
    // Output: Original: [5, 2, 8, 1]
    //         Sorted: [1, 2, 5, 8]
    
    // Filter and transform
    var transformed = try ranges.ArrayRange(i32).init(list.items)
        .filter(isEven)
        .map(square)
        .collect(allocator);
    defer transformed.deinit(allocator);
    
    std.debug.print("Evens squared: {any}\n", .{transformed.items});
    // Output: Evens squared: [4, 64]
}
```

### Collecting to Different Types

```zig
const std = @import("std");
const ranges = @import("ranges");

fn square(x: i32) i32 {
    return x * x;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Collect to ArrayList
    var arrayList = try ranges.Range(i32).init(1, 6)
        .map(square)
        .collect(allocator);
    defer arrayList.deinit(allocator);
    std.debug.print("ArrayList: {any}\n", .{arrayList.items});
    // Output: ArrayList: [1, 4, 9, 16, 25]
    
    // Collect to owned slice
    const slice = try ranges.Range(i32).init(1, 6)
        .map(square)
        .collectSlice(allocator);
    defer allocator.free(slice);
    std.debug.print("Slice: {any}\n", .{slice});
    // Output: Slice: [1, 4, 9, 16, 25]
    
    // Collect to fixed-size array
    const array = try ranges.Range(i32).init(1, 6)
        .map(square)
        .collectArray(5);
    std.debug.print("Array: {any}\n", .{array});
    // Output: Array: [1, 4, 9, 16, 25]
}
```

## Common Use Cases

### Data Processing Pipeline

Process a collection through multiple transformation steps:

```zig
const data = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

var result = try ranges.ArrayRange(i32).init(&data)
    .filter(isEven)           // Keep only even numbers
    .map(square)              // Square each number  
    .filter(lessThan50)       // Keep only values < 50
    .sorted(allocator);       // Sort the results
defer result.deinit(allocator);
```

### Statistical Operations

Calculate statistics over a range:

```zig
// Average using fold
const sum = ranges.Range(i32).init(1, 11).fold(0, add);
const avg = @divTrunc(sum, 10);

// Count elements matching criteria
const evenCount = ranges.Range(i32).init(1, 101)
    .filter(isEven)
    .count();

// Check for outliers
const hasOutlier = ranges.ArrayRange(i32).init(&measurements)
    .any(isOutlier);
```

### Validation

Check if data meets criteria:

```zig
const allValid = ranges.ArrayRange(User).init(&users)
    .all(User.isValid);

const hasAdmin = ranges.ArrayRange(User).init(&users)
    .any(User.isAdmin);
```

### Data Transformation

Transform collections efficiently:

```zig
// Convert array of structs to array of specific fields
var ages = try ranges.ArrayRange(Person).init(&people)
    .map(Person.getAge)
    .sorted(allocator);
defer ages.deinit(allocator);

// Normalize data
var normalized = try ranges.ArrayRange(f32).init(&values)
    .map(normalize)
    .collectSlice(allocator);
defer allocator.free(normalized);
```

## API Reference

### `Range(T)`

Creates a numeric range iterator.

**Constructor:**
- `init(start: T, end: T)` - Create a range from start (inclusive) to end (exclusive)

**Iterator Methods:**
- `next()` - Get the next value, returns `?T`

**Transformation Methods:**
- `map(comptime F)` - Transform each element using function `F`
- `filter(comptime P)` - Keep only elements matching predicate `P`

**Collection Methods:**
- `collect(allocator)` - Collect all elements into an `ArrayList(T)`
- `collectSlice(allocator)` - Collect all elements into an owned slice `[]T`
- `collectArray(comptime size: usize)` - Collect all elements into a fixed-size array `[size]T`

**Search Methods:**
- `find(value: T)` - Find a specific value, returns `?T`
- `any(comptime P)` - Check if any element matches predicate `P`, returns `bool`
- `all(comptime P)` - Check if all elements match predicate `P`, returns `bool`
- `count()` - Count the number of elements, returns `usize`

**Aggregation Methods:**
- `fold(init: T, comptime F)` - Reduce elements using function `F` with initial value `init`

**Sorting Methods:**
- `sorted(allocator)` - Sort elements and return `ArrayList(T)` (for primitive types)
- `sortedSlice(allocator)` - Sort elements and return owned slice `[]T` (for primitive types)
- `sortedBy(allocator, comptime lessThan)` - Sort using custom comparison function
- `sortedSliceBy(allocator, comptime lessThan)` - Sort using custom comparison, return slice
- `sortedWith(allocator, comptime lessThan, context)` - Sort with context parameter
- `sortedSliceWith(allocator, comptime lessThan, context)` - Sort with context, return slice

### `ArrayRange(T)`

Creates an iterator over array/slice elements.

**Constructor:**
- `init(arr: []const T)` - Create an iterator from a slice or array

**All the same methods as `Range(T)` are available**

### Predicate and Transform Functions

Functions passed to `filter`, `map`, `any`, `all`, and `fold` should follow these signatures:

```zig
// Predicate: takes T, returns bool
fn predicate(value: T) bool

// Transform: takes T, returns U (can be same or different type)
fn transform(value: T) U

// Fold: takes accumulator and value, returns accumulator
fn foldFunc(acc: T, value: T) T

// Comparison: takes two T, returns bool (true if a < b)
fn lessThan(a: T, b: T) bool
```

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

- Zig 0.13.0 or later

## Performance Notes

- **Lazy Evaluation**: `map` and `filter` operations are lazy - they don't execute until you iterate or collect
- **Zero-Copy Iteration**: Basic iteration over ranges and arrays has zero allocation overhead
- **Efficient Sorting**: Uses Zig's standard library sorting (Tim sort variant) - O(n log n) time complexity
- **Allocation**: Only collection operations (`collect`, `collectSlice`) and sorting require memory allocation

## License

This project is open source.

## Examples

See `src/main.zig` for a complete working example and `src/ranges_test.zig` for more usage patterns.