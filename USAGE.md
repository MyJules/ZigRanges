# Using ZigRanges in Your Project

This guide shows you how to integrate ZigRanges into your Zig project.

## Project Structure

Your project should look like this:

```
your-project/
├── build.zig
├── src/
│   └── main.zig
└── libs/
    └── ZigRanges/
        ├── build.zig
        └── src/
            └── ranges.zig
```

## Step 1: Add ZigRanges to Your Project

### Method 1: Using Zig Package Manager (Recommended)

**Create or update `build.zig.zon` in your project root:**

```zig
.{
    .name = "your-project",
    .version = "0.1.0",
    .dependencies = .{
        .ranges = .{
            .url = "https://github.com/yourusername/ZigRanges/archive/refs/tags/v0.1.0.tar.gz",
            .hash = "1220...", // Zig will provide the correct hash on first build
        },
    },
}
```

**Note:** On first build, Zig will tell you the correct hash. Copy it into your `build.zig.zon`.

### Method 2: Local Development Path

If you have the library locally or as a submodule:

```zig
.{
    .name = "your-project",
    .version = "0.1.0",
    .dependencies = .{
        .ranges = .{
            .path = "libs/ZigRanges",
        },
    },
}
```

### Method 3: Git Submodule (Optional)

```bash
git submodule add https://github.com/yourusername/ZigRanges libs/ZigRanges
```

Then use Method 2 (local path) in your `build.zig.zon`.

## Step 2: Update Your build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Import the ranges dependency
    const ranges = b.dependency("ranges", .{
        .target = target,
        .optimize = optimize,
    }).module("ranges");

    // Create your executable
    const exe = b.addExecutable(.{
        .name = "your-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add ranges module to your executable
    exe.root_module.addImport("ranges", ranges);

    b.installArtifact(exe);

    // Optional: Add run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Optional: Add tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.root_module.addImport("ranges", ranges);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
```

## Step 3: Use in Your Code

Create `src/main.zig`:

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

    // Example 1: Simple range with filter and map
    std.debug.print("Example 1: Filter and map\n", .{});
    var iter1 = ranges.Range(i32).init(0, 10)
        .filter(isEven)
        .map(square);
    
    while (iter1.next()) |value| {
        std.debug.print("{} ", .{value});
    }
    std.debug.print("\n\n", .{});

    // Example 2: Collect results
    std.debug.print("Example 2: Collect into ArrayList\n", .{});
    var result = try ranges.Range(i32).init(1, 11)
        .filter(isEven)
        .collect(allocator);
    defer result.deinit(allocator);
    
    std.debug.print("Collected: {any}\n\n", .{result.items});

    // Example 3: Sort array
    std.debug.print("Example 3: Sort array\n", .{});
    const array = [_]i32{ 5, 2, 8, 1, 9, 3, 7 };
    var sorted = try ranges.ArrayRange(i32).init(&array)
        .sorted(allocator);
    defer sorted.deinit(allocator);
    
    std.debug.print("Original: {any}\n", .{array});
    std.debug.print("Sorted: {any}\n\n", .{sorted.items});

    // Example 4: Custom type sorting
    std.debug.print("Example 4: Custom type sorting\n", .{});
    const Person = struct {
        name: []const u8,
        age: u32,
        
        fn compareByAge(a: @This(), b: @This()) bool {
            return a.age < b.age;
        }
    };

    const people = [_]Person{
        .{ .name = "Alice", .age = 30 },
        .{ .name = "Bob", .age = 25 },
        .{ .name = "Charlie", .age = 35 },
    };

    var sorted_people = try ranges.ArrayRange(Person).init(&people)
        .sortedBy(allocator, Person.compareByAge);
    defer sorted_people.deinit(allocator);

    for (sorted_people.items) |p| {
        std.debug.print("{s}: {}\n", .{ p.name, p.age });
    }
}
```

## Step 4: Build and Run

```bash
# Build your project
zig build

# Run your project
zig build run

# Run tests (if configured)
zig build test
```

## Common Patterns

### Working with ArrayList

```zig
var list = try std.ArrayList(i32).initCapacity(allocator, 10);
defer list.deinit(allocator);

try list.append(allocator, 1);
try list.append(allocator, 2);
try list.append(allocator, 3);

// Use ranges with ArrayList.items
var iter = ranges.ArrayRange(i32).init(list.items)
    .map(square);
```

### Chaining Multiple Operations

```zig
var result = try ranges.Range(i32).init(0, 100)
    .filter(isEven)
    .map(square)
    .filter(isLessThan(1000))
    .sorted(allocator);
defer result.deinit(allocator);
```

### Using fold for Aggregation

```zig
fn add(acc: i32, x: i32) i32 {
    return acc + x;
}

const sum = ranges.Range(i32).init(1, 11)
    .fold(add, 0);

std.debug.print("Sum: {}\n", .{sum}); // Output: Sum: 55
```

### Checking Conditions

```zig
const hasNegative = ranges.Range(i32).init(-5, 5)
    .any(struct {
        fn f(x: i32) bool {
            return x < 0;
        }
    }.f);

const allPositive = ranges.Range(i32).init(1, 10)
    .all(struct {
        fn f(x: i32) bool {
            return x > 0;
        }
    }.f);
```

## Tips

1. **Memory Management**: Always defer cleanup for collected results:
   ```zig
   var result = try iter.collect(allocator);
   defer result.deinit(allocator);
   ```

2. **Lazy Evaluation**: `map()` and `filter()` don't execute until you call terminal operations like `next()`, `collect()`, or `sorted()`.

3. **Type Inference**: Let Zig infer types when possible:
   ```zig
   var iter = ranges.Range(i32).init(0, 10); // Type is inferred
   ```

4. **Custom Comparisons**: For simple cases, use `sortedBy()`. For complex cases needing context, use `sortedWith()`.

## Troubleshooting

### "Module not found" Error

Make sure the path in `build.zig` matches your directory structure:
```zig
.root_source_file = b.path("libs/ZigRanges/src/ranges.zig"),
```

### "Out of memory" Error

Make sure you're using `defer` to clean up:
```zig
var result = try iter.collect(allocator);
defer result.deinit(allocator);
```

### Type Mismatch Errors

Ensure your functions match the expected signatures:
- Predicates: `fn(T) bool`
- Transformations: `fn(T) U`
- Comparisons: `fn(T, T) bool`

## Next Steps

- Check out the full [API Reference](Readme.md#api-reference)
- See [examples](src/main.zig) for more patterns
- Run tests with `zig build test` to explore all features
