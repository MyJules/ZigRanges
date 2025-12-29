# ZigRanges Example Project

This example project demonstrates how to use the ZigRanges library in your own applications.

## Project Structure

```
example/
├── build.zig          # Build configuration
├── src/
│   └── main.zig       # Example code demonstrating all features
└── README.md          # This file
```

## Building and Running

From the `example` directory:

```bash
# Build the example
zig build

# Run the example
zig build run
```

## What's Demonstrated

This example shows **10 comprehensive use cases**:

### 1. Basic Filter and Map
- Creating ranges
- Filtering with predicates
- Mapping transformations

### 2. Array Range Operations
- Working with arrays and slices
- Chaining operations on arrays

### 3. Collecting Results
- `collect()` - into ArrayList
- `collectSlice()` - into owned slice
- `collectArray(N)` - into fixed-size array

### 4. Sorting Primitives
- Sorting integers, floats
- Sorting filtered results

### 5. Custom Type Sorting
- Defining custom comparison functions
- Sorting structs by different fields
- Using `sortedBy()`

### 6. Complex Operation Chains
- Chaining multiple operations
- Filtering, mapping, and sorting together
- Real-world patterns

### 7. Fold Operations
- Summing values
- Computing products
- Aggregating results

### 8. Any and All Predicates
- `any()` - check if any element matches
- `all()` - check if all elements match
- Combining with filters

### 9. Count and Find
- `count()` - count elements
- `find()` - search for specific values
- Working with custom types

### 10. Working with ArrayList
- Using ranges with std.ArrayList
- Converting between ArrayList and ranges
- Practical integration patterns

## Key Takeaways

### Import the Library
```zig
const ranges = @import("ranges");
```

### Basic Pattern
```zig
var result = try ranges.Range(i32).init(0, 10)
    .filter(isEven)
    .map(square)
    .collect(allocator);
defer result.deinit(allocator);
```

### Always Defer Cleanup
```zig
var result = try iter.collect(allocator);
defer result.deinit(allocator);  // Important!
```

### Lazy Evaluation
Operations like `map()` and `filter()` don't execute until you call a terminal operation (`collect()`, `next()`, `sorted()`, etc.).

## Using This as a Template

You can copy this example directory as a starting point for your own project:

1. Copy the `example` directory to your new project location
2. Update `build.zig` to point to wherever you've installed ZigRanges
3. Modify `src/main.zig` with your application logic

## Build Configuration

The `build.zig` shows how to:
- Import the ranges module from a relative path
- Add it to your executable's imports
- Configure build options

```zig
const ranges = b.addModule("ranges", .{
    .root_source_file = b.path("../src/ranges.zig"),
});
exe.root_module.addImport("ranges", ranges);
```

## More Resources

- [Main README](../Readme.md) - Full API documentation
- [USAGE Guide](../USAGE.md) - Integration guide
- [Source Code](../src/ranges.zig) - Library implementation with inline documentation
