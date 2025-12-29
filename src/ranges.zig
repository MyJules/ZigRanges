// ranges.zig - A Zig library for functional-style iterator operations
//
// This library provides Range and ArrayRange types with chainable operations
// similar to Rust's iterators or C++'s ranges. It supports lazy evaluation
// and composable transformations like map, filter, fold, and more.
//
// Example Usage:
//   const range = Range(usize).init(0, 10);
//   var iter = range
//       .filter(isEven)
//       .map(square);
//   while (iter.next()) |value| {
//       // Process transformed values
//   }
//
// Custom Type Sorting:
//   const Person = struct {
//       name: []const u8,
//       age: u32,
//       fn compareByAge(a: Person, b: Person) bool {
//           return a.age < b.age;
//       }
//   };
//   var sorted = try people.sortedBy(allocator, Person.compareByAge);
//
// ============================================================================
// API Overview
// ============================================================================
//
// Core Iterator Types:
//   - Range(T): Iterate over numeric ranges [start, end)
//   - ArrayRange(T): Iterate over slices/arrays
//
// Working with std containers:
//   ArrayRange works with any std container that exposes a slice:
//   - ArrayList: use .items to get the slice
//   - BoundedArray: use .slice() or .constSlice()
//   - Static arrays: pass &array or array[0..]
//
//   Example with ArrayList:
//     var list = try std.ArrayList(i32).initCapacity(allocator, 10);
//     var iter = ArrayRange(i32).init(list.items);
//
// Transformation Operations (return new iterators):
//   - map(F): Transform each element with function F
//   - filter(P): Keep only elements where predicate P returns true
//
// Terminal Operations (consume iterator and return a value):
//   - next(): Get the next element (Option<T>)
//   - find(value): Search for a specific value
//   - collect(allocator): Gather into ArrayList
//   - collectSlice(allocator): Gather into owned slice
//   - collectArray(N): Gather into fixed [N]T array
//   - count(): Count number of elements
//   - any(P): Check if any element satisfies predicate P
//   - all(P): Check if all elements satisfy predicate P
//   - fold(F, initial): Reduce to single value with folding function F
//   - sorted(allocator): Sort elements and return ArrayList (uses std.mem.sort)
//   - sortedSlice(allocator): Sort elements and return owned slice
//   - sortedBy(allocator, cmpFn): Sort with custom comparison (no context)
//   - sortedSliceBy(allocator, cmpFn): Sort with custom comparison, return slice
//   - sortedWith(allocator, cmpFn, ctx): Sort with comparison + context (advanced)
//   - sortedSliceWith(allocator, cmpFn, ctx): Sort with comparison + context, return slice
//
// All operations support method chaining and lazy evaluation.
//
// ============================================================================

const std = @import("std");

/// --- Helper Functions ---
/// Extract function type information from a compile-time function.
/// This is used internally to determine parameter and return types for
/// generic iterator operations.
///
/// Parameters:
///   - F: A compile-time function to analyze
///
/// Returns: The function type information from @typeInfo
///
/// Panics: Compile error if F is not a function type
fn getFnInfo(comptime F: anytype) @TypeOf(@typeInfo(@TypeOf(F)).@"fn") {
    const ti = @typeInfo(@TypeOf(F));
    if (ti != .@"fn") @compileError("expected function");
    return ti.@"fn";
}

/// --- Iterator Mixin ---
/// Generates common iterator operations for any type with a next() method.
/// This mixin provides a consistent set of operations (map, filter, find, etc.)
/// that can be used with any iterator type.
///
/// Type parameter T: The element type yielded by the iterator
///
/// This function returns a type containing operations that should be mixed into
/// iterator types. Each operation returns a new iterator or performs a terminal
/// operation on the iterator.
///
/// Available operations:
///   - map: Transform each element
///   - filter: Keep only elements matching a predicate
///   - find: Search for a specific value
///   - collect: Gather all elements into an ArrayList
///   - collectSlice: Gather all elements into a slice
///   - collectArray: Gather all elements into a fixed-size array
///   - count: Count the number of elements
///   - any: Check if any element matches a predicate
///   - all: Check if all elements match a predicate
///   - fold: Reduce all elements to a single value
///   - sorted: Sort elements and return ArrayList
///   - sortedSlice: Sort elements and return owned slice
///   - sortedBy: Sort with custom comparison function
///   - sortedSliceBy: Sort with custom comparison, return slice
///   - sortedWith: Sort with custom comparison + context (advanced)
///   - sortedSliceWith: Sort with custom comparison + context, return slice
fn IteratorOps(comptime T: type) type {
    return struct {
        /// Transform each element using the provided function.
        /// Returns a new MapIterator that lazily applies F to each element.
        ///
        /// Parameters:
        ///   - F: A compile-time function that transforms values of type T
        ///
        /// Example:
        ///   iter.map(square)  // where square(x) returns x*x
        pub fn map(self: anytype, comptime F: anytype) MapIterator(@TypeOf(self.*), F) {
            return MapIterator(@TypeOf(self.*), F).init(self.*);
        }

        /// Keep only elements that satisfy the predicate function.
        /// Returns a new FilterIterator that lazily filters elements.
        ///
        /// Parameters:
        ///   - P: A compile-time predicate function that returns bool
        ///
        /// Example:
        ///   iter.filter(isEven)  // where isEven(x) returns x % 2 == 0
        pub fn filter(self: anytype, comptime P: anytype) FilterIterator(@TypeOf(self.*), P) {
            return FilterIterator(@TypeOf(self.*), P).init(self.*);
        }

        /// Search for a specific value in the iterator.
        /// Returns the first occurrence of the value, or null if not found.
        /// This is a terminal operation that consumes the iterator.
        ///
        /// Parameters:
        ///   - value: The value to search for
        ///
        /// Returns: The found value or null
        pub fn find(self: anytype, value: T) ?T {
            var iter = self.*;
            while (iter.next()) |v| {
                if (eq(T, value, v)) return v;
            }
            return null;
        }

        /// Gather all elements into an ArrayList.
        /// This is a terminal operation that consumes the iterator.
        ///
        /// Parameters:
        ///   - allocator: Memory allocator for the ArrayList
        ///
        /// Returns: ArrayList containing all elements
        ///
        /// Note: Caller is responsible for calling deinit() on the returned ArrayList
        pub fn collect(self: anytype, allocator: std.mem.Allocator) !std.ArrayList(T) {
            var results = try std.ArrayList(T).initCapacity(allocator, 0);
            var iter = self.*;
            while (iter.next()) |v| {
                try results.append(allocator, v);
            }
            return results;
        }

        /// Collect all elements into a slice.
        /// This is a terminal operation that consumes the iterator.
        ///
        /// Parameters:
        ///   - allocator: Memory allocator for the slice
        ///
        /// Returns: Slice containing all elements (caller owns memory)
        ///
        /// Note: Caller must free the returned slice using allocator.free()
        pub fn collectSlice(self: anytype, allocator: std.mem.Allocator) ![]T {
            var list = try self.collect(allocator);
            defer list.deinit(allocator);
            return list.toOwnedSlice(allocator);
        }

        /// Collect all elements into a fixed-size array.
        /// This is a terminal operation that consumes the iterator.
        ///
        /// Parameters:
        ///   - N: The compile-time size of the array
        ///
        /// Returns: Array of exactly N elements
        ///
        /// Errors:
        ///   - TooManyElements: Iterator yields more than N elements
        ///   - TooFewElements: Iterator yields fewer than N elements
        pub fn collectArray(self: anytype, comptime N: usize) ![N]T {
            var result: [N]T = undefined;
            var iter = self.*;
            var i: usize = 0;
            while (iter.next()) |v| : (i += 1) {
                if (i >= N) return error.TooManyElements;
                result[i] = v;
            }
            if (i < N) return error.TooFewElements;
            return result;
        }

        /// Count the number of elements in the iterator.
        /// This is a terminal operation that consumes the iterator.
        ///
        /// Returns: The total number of elements
        pub fn count(self: anytype) usize {
            var cnt: usize = 0;
            var iter = self.*;
            while (iter.next()) |_| cnt += 1;
            return cnt;
        }

        /// Check if any element satisfies the predicate.
        /// This is a terminal operation that consumes the iterator.
        /// Short-circuits on first match.
        ///
        /// Parameters:
        ///   - P: A compile-time predicate function that returns bool
        ///
        /// Returns: true if at least one element satisfies P, false otherwise
        pub fn any(self: anytype, comptime P: anytype) bool {
            var iter = self.*;
            while (iter.next()) |v| if (P(v)) return true;
            return false;
        }

        /// Check if all elements satisfy the predicate.
        /// This is a terminal operation that consumes the iterator.
        /// Short-circuits on first non-match.
        ///
        /// Parameters:
        ///   - P: A compile-time predicate function that returns bool
        ///
        /// Returns: true if all elements satisfy P, false otherwise
        pub fn all(self: anytype, comptime P: anytype) bool {
            var iter = self.*;
            while (iter.next()) |v| if (!P(v)) return false;
            return true;
        }

        /// Reduce all elements to a single value using a folding function.
        /// This is a terminal operation that consumes the iterator.
        ///
        /// Parameters:
        ///   - F: A compile-time function (accumulator, element) -> accumulator
        ///   - initial: The initial accumulator value
        ///
        /// Returns: The final accumulated value
        ///
        /// Example:
        ///   iter.fold(add, 0)  // Sum all elements
        ///   iter.fold(multiply, 1)  // Product of all elements
        pub fn fold(self: anytype, comptime F: anytype, initial: anytype) @TypeOf(initial) {
            var acc = initial;
            var iter = self.*;
            while (iter.next()) |v| acc = F(acc, v);
            return acc;
        }

        /// Collect and sort all elements into an ArrayList.
        /// This is a terminal operation that consumes the iterator.
        /// Uses std.mem.sort with an optimal sorting algorithm.
        ///
        /// Parameters:
        ///   - allocator: Memory allocator for the ArrayList
        ///
        /// Returns: ArrayList containing all elements in sorted order
        ///
        /// Note: Caller is responsible for calling deinit() on the returned ArrayList.
        ///       Type T must be comparable (supports <, >, ==).
        ///
        /// Performance: O(n log n) time complexity using std.mem.sort
        pub fn sorted(self: anytype, allocator: std.mem.Allocator) !std.ArrayList(T) {
            const results = try self.collect(allocator);
            std.mem.sort(T, results.items, {}, comptime lessThan(T));
            return results;
        }

        /// Collect and sort all elements into a slice.
        /// This is a terminal operation that consumes the iterator.
        ///
        /// Parameters:
        ///   - allocator: Memory allocator for the slice
        ///
        /// Returns: Owned slice containing all elements in sorted order
        ///
        /// Note: Caller must free the returned slice using allocator.free().
        ///       Type T must be comparable (supports <, >, ==).
        ///
        /// Performance: O(n log n) time complexity using std.mem.sort
        pub fn sortedSlice(self: anytype, allocator: std.mem.Allocator) ![]T {
            var list = try self.sorted(allocator);
            defer list.deinit(allocator);
            return list.toOwnedSlice(allocator);
        }

        /// Collect and sort all elements using a custom comparison function.
        /// Simplified version without context for common cases.
        /// This is a terminal operation that consumes the iterator.
        ///
        /// Parameters:
        ///   - allocator: Memory allocator for the ArrayList
        ///   - comptime lessThanFn: Comparison function (a, b) -> bool
        ///                          Returns true if a should come before b
        ///
        /// Returns: ArrayList containing all elements in sorted order
        ///
        /// Note: Works with any type, including custom structs.
        ///       Caller is responsible for calling deinit() on the returned ArrayList.
        ///       For comparison functions that need extra data, use sortedWith().
        ///
        /// Example:
        ///   sortedBy(allocator, comparePerson)
        ///   where comparePerson = fn(a: Person, b: Person) bool
        ///
        /// Performance: O(n log n) time complexity using std.mem.sort
        pub fn sortedBy(
            self: anytype,
            allocator: std.mem.Allocator,
            comptime lessThanFn: anytype,
        ) !std.ArrayList(T) {
            const Wrapper = struct {
                fn compare(_: void, a: T, b: T) bool {
                    return lessThanFn(a, b);
                }
            };
            return self.sortedWith(allocator, Wrapper.compare, {});
        }

        /// Collect and sort all elements using a custom comparison function with context.
        /// This is a terminal operation that consumes the iterator.
        ///
        /// Parameters:
        ///   - allocator: Memory allocator for the ArrayList
        ///   - comptime lessThanFn: Comparison function (context, a, b) -> bool
        ///                          Returns true if a should come before b
        ///   - context: Context passed to the comparison function
        ///
        /// Returns: ArrayList containing all elements in sorted order
        ///
        /// Note: Use this when your comparison function needs external data.
        ///       For simple comparisons, use sortedBy() instead.
        ///       Caller is responsible for calling deinit() on the returned ArrayList.
        ///
        /// Example:
        ///   const ctx = SortContext{ .scores = &scores };
        ///   sortedWith(allocator, compareByScore, ctx)
        ///   where compareByScore = fn(ctx: SortContext, a: T, b: T) bool
        ///
        /// Performance: O(n log n) time complexity using std.mem.sort
        pub fn sortedWith(
            self: anytype,
            allocator: std.mem.Allocator,
            comptime lessThanFn: anytype,
            context: anytype,
        ) !std.ArrayList(T) {
            const results = try self.collect(allocator);
            std.mem.sort(T, results.items, context, lessThanFn);
            return results;
        }

        /// Collect and sort all elements into a slice using a custom comparison function.
        /// Simplified version without context for common cases.
        /// This is a terminal operation that consumes the iterator.
        ///
        /// Parameters:
        ///   - allocator: Memory allocator for the slice
        ///   - comptime lessThanFn: Comparison function (a, b) -> bool
        ///
        /// Returns: Owned slice containing all elements in sorted order
        ///
        /// Note: Caller must free the returned slice using allocator.free()
        ///       For comparison functions that need extra data, use sortedSliceWith().
        ///
        /// Performance: O(n log n) time complexity using std.mem.sort
        pub fn sortedSliceBy(
            self: anytype,
            allocator: std.mem.Allocator,
            comptime lessThanFn: anytype,
        ) ![]T {
            var list = try self.sortedBy(allocator, lessThanFn);
            defer list.deinit(allocator);
            return list.toOwnedSlice(allocator);
        }

        /// Collect and sort all elements into a slice using a custom comparison function with context.
        /// This is a terminal operation that consumes the iterator.
        ///
        /// Parameters:
        ///   - allocator: Memory allocator for the slice
        ///   - comptime lessThanFn: Comparison function (context, a, b) -> bool
        ///   - context: Context passed to the comparison function
        ///
        /// Returns: Owned slice containing all elements in sorted order
        ///
        /// Note: Caller must free the returned slice using allocator.free()
        ///
        /// Performance: O(n log n) time complexity using std.mem.sort
        pub fn sortedSliceWith(
            self: anytype,
            allocator: std.mem.Allocator,
            comptime lessThanFn: anytype,
            context: anytype,
        ) ![]T {
            var list = try self.sortedWith(allocator, lessThanFn, context);
            defer list.deinit(allocator);
            return list.toOwnedSlice(allocator);
        }
    };
}

/// Generic less-than comparison for sortable types.
/// Used by the sorted() operations to compare elements.
///
/// Supports:
///   - Numeric types (int, float)
///   - Booleans (false < true)
///
/// Parameters:
///   - T: The type to compare
///
/// Returns: A comparison function compatible with std.mem.sort
fn lessThan(comptime T: type) fn (void, T, T) bool {
    return struct {
        fn inner(_: void, a: T, b: T) bool {
            const info = @typeInfo(T);
            return switch (info) {
                .int, .float => a < b,
                .bool => !a and b, // false < true
                else => @compileError("sorted() requires a comparable type (int, float, or bool)"),
            };
        }
    }.inner;
}

/// --- ArrayRange Iterator ---
/// An iterator over a slice of elements.
/// Provides functional-style operations on arrays/slices with lazy evaluation.
///
/// Type parameter T: The element type of the slice
///
/// Example:
///   const array = [_]i32{ 1, 2, 3, 4, 5 };
///   var iter = ArrayRange(i32).init(&array);
///   while (iter.next()) |value| {
///       // Process each value
///   }
///
/// All operations from IteratorOps are available:
///   var doubled = iter.map(double);
///   var evens = iter.filter(isEven);
///   const sum = iter.fold(add, 0);
pub fn ArrayRange(comptime T: type) type {
    return struct {
        arr: []const T,
        index: usize,

        const Ops = IteratorOps(T);

        /// Create a new ArrayRange iterator over the given slice.
        ///
        /// Parameters:
        ///   - arr: The slice to iterate over
        ///
        /// Returns: A new ArrayRange iterator positioned at the start
        pub fn init(arr: []const T) @This() {
            return .{ .arr = arr, .index = 0 };
        }

        /// Advance the iterator and return the next element.
        ///
        /// Returns: The next element, or null if the iterator is exhausted
        pub fn next(self: *@This()) ?T {
            if (self.index >= self.arr.len) return null;
            const v = self.arr[self.index];
            self.index += 1;
            return v;
        }

        pub const map = Ops.map;
        pub const filter = Ops.filter;
        pub const find = Ops.find;
        pub const collect = Ops.collect;
        pub const collectSlice = Ops.collectSlice;
        pub const collectArray = Ops.collectArray;
        pub const count = Ops.count;
        pub const any = Ops.any;
        pub const all = Ops.all;
        pub const fold = Ops.fold;
        pub const sorted = Ops.sorted;
        pub const sortedSlice = Ops.sortedSlice;
        pub const sortedBy = Ops.sortedBy;
        pub const sortedSliceBy = Ops.sortedSliceBy;
        pub const sortedWith = Ops.sortedWith;
        pub const sortedSliceWith = Ops.sortedSliceWith;
    };
}

/// --- Range Iterator ---
/// An iterator over a numeric range [start, end).
/// Generates values from start (inclusive) to end (exclusive).
///
/// Type parameter T: The numeric type (must support += 1 and >= comparison)
///
/// Example:
///   var iter = Range(usize).init(0, 10);  // Yields 0, 1, 2, ..., 9
///   while (iter.next()) |value| {
///       // Process each value
///   }
///
/// Chaining operations:
///   const result = Range(i32).init(1, 100)
///       .filter(isEven)
///       .map(square)
///       .collect(allocator);
pub fn Range(comptime T: type) type {
    return struct {
        start: T,
        end: T,

        const Ops = IteratorOps(T);

        /// Create a new Range iterator for the interval [start, end).
        ///
        /// Parameters:
        ///   - start: First value to yield (inclusive)
        ///   - end: Upper bound (exclusive)
        ///
        /// Returns: A new Range iterator
        ///
        /// Note: If start >= end, the iterator is immediately exhausted
        pub fn init(start: T, end: T) @This() {
            return @This(){ .start = start, .end = end };
        }

        /// Advance the iterator and return the next value in the range.
        ///
        /// Returns: The next value, or null if the range is exhausted
        pub fn next(self: *@This()) ?T {
            if (self.start >= self.end) return null;
            const v = self.start;
            self.start += 1;
            return v;
        }

        pub const map = Ops.map;
        pub const filter = Ops.filter;
        pub const find = Ops.find;
        pub const collect = Ops.collect;
        pub const collectSlice = Ops.collectSlice;
        pub const collectArray = Ops.collectArray;
        pub const count = Ops.count;
        pub const any = Ops.any;
        pub const all = Ops.all;
        pub const fold = Ops.fold;
        pub const sorted = Ops.sorted;
        pub const sortedSlice = Ops.sortedSlice;
        pub const sortedBy = Ops.sortedBy;
        pub const sortedSliceBy = Ops.sortedSliceBy;
        pub const sortedWith = Ops.sortedWith;
        pub const sortedSliceWith = Ops.sortedSliceWith;
    };
}

/// --- MapIterator ---
/// An iterator that applies a transformation function to elements from an inner iterator.
/// Created by calling .map() on any iterator.
///
/// This iterator lazily applies the transformation - the function is only called
/// when next() is invoked, not when the iterator is created.
///
/// Type parameters:
///   - Inner: The type of the source iterator
///   - F: The compile-time transformation function
///
/// The output type is automatically inferred from F's return type.
fn MapIterator(comptime Inner: type, comptime F: anytype) type {
    const info = getFnInfo(F);
    const Out = info.return_type.?;

    return struct {
        inner: Inner,

        const Ops = IteratorOps(Out);

        /// Create a new MapIterator wrapping an inner iterator.
        /// Typically not called directly - use iterator.map() instead.
        ///
        /// Parameters:
        ///   - inner: The source iterator to transform
        ///
        /// Returns: A new MapIterator
        pub fn init(inner: Inner) @This() {
            return .{ .inner = inner };
        }

        /// Get the next transformed element.
        ///
        /// Returns: F applied to the next element from the inner iterator,
        ///          or null if the inner iterator is exhausted
        pub fn next(self: *@This()) ?Out {
            const v = self.inner.next() orelse return null;
            return F(v);
        }

        pub const map = Ops.map;
        pub const filter = Ops.filter;
        pub const find = Ops.find;
        pub const collect = Ops.collect;
        pub const collectSlice = Ops.collectSlice;
        pub const collectArray = Ops.collectArray;
        pub const count = Ops.count;
        pub const any = Ops.any;
        pub const all = Ops.all;
        pub const fold = Ops.fold;
        pub const sorted = Ops.sorted;
        pub const sortedSlice = Ops.sortedSlice;
        pub const sortedBy = Ops.sortedBy;
        pub const sortedSliceBy = Ops.sortedSliceBy;
        pub const sortedWith = Ops.sortedWith;
        pub const sortedSliceWith = Ops.sortedSliceWith;
    };
}

/// --- FilterIterator ---
/// An iterator that filters elements from an inner iterator using a predicate.
/// Created by calling .filter() on any iterator.
///
/// This iterator lazily filters elements - the predicate is only evaluated
/// when next() is invoked, not when the iterator is created.
///
/// Type parameters:
///   - Inner: The type of the source iterator
///   - P: The compile-time predicate function (element) -> bool
///
/// Elements are yielded only if P returns true.
fn FilterIterator(comptime Inner: type, comptime P: anytype) type {
    const info = getFnInfo(P);
    const T = info.params[0].type.?;

    return struct {
        inner: Inner,

        const Ops = IteratorOps(T);

        /// Create a new FilterIterator wrapping an inner iterator.
        /// Typically not called directly - use iterator.filter() instead.
        ///
        /// Parameters:
        ///   - inner: The source iterator to filter
        ///
        /// Returns: A new FilterIterator
        pub fn init(inner: Inner) @This() {
            return .{ .inner = inner };
        }

        /// Get the next element that satisfies the predicate.
        /// Internally advances the inner iterator until a matching element is found.
        ///
        /// Returns: The next element where P(element) is true,
        ///          or null if no more matching elements exist
        pub fn next(self: *@This()) ?T {
            while (self.inner.next()) |v| if (P(v)) return v;
            return null;
        }

        pub const map = Ops.map;
        pub const filter = Ops.filter;
        pub const find = Ops.find;
        pub const collect = Ops.collect;
        pub const collectSlice = Ops.collectSlice;
        pub const collectArray = Ops.collectArray;
        pub const count = Ops.count;
        pub const any = Ops.any;
        pub const all = Ops.all;
        pub const fold = Ops.fold;
        pub const sorted = Ops.sorted;
        pub const sortedSlice = Ops.sortedSlice;
        pub const sortedBy = Ops.sortedBy;
        pub const sortedSliceBy = Ops.sortedSliceBy;
        pub const sortedWith = Ops.sortedWith;
        pub const sortedSliceWith = Ops.sortedSliceWith;
    };
}

/// Generic equality comparison for supported types.
/// Used internally by find() to compare values.
///
/// Supports:
///   - Primitive numeric types (int, float)
///   - Booleans
///   - Enum literals
///   - Structs (field-by-field comparison)
///   - Pointers (address comparison)
///   - Arrays (element-wise comparison)
///
/// Parameters:
///   - T: The type to compare
///   - a, b: Values to compare
///
/// Returns: true if values are equal, false otherwise
///
/// Panics: Compile error for unsupported types
fn eq(comptime T: type, a: T, b: T) bool {
    const info = @typeInfo(T);

    switch (info) {
        // Primitive numeric types, booleans, enum literals
        .int, .float, .bool, .enum_literal => return a == b,

        // Structs: recursively compare field by field
        .@"struct" => {
            inline for (info.@"struct".fields) |field| {
                if (!eq(field.type, @field(a, field.name), @field(b, field.name))) return false;
            }
            return true;
        },

        // Pointers: compare addresses
        .pointer => return a == b,

        // Arrays: compare element-wise
        .array => {
            inline for (a, 0..) |val, i| {
                if (!eq(@TypeOf(val), val, b[i])) return false;
            }
            return true;
        },

        else => @compileError("eq: unsupported type"),
    }
}

// ============================================================================
// Tests
// ============================================================================
// The following tests demonstrate usage patterns and validate functionality

test "test range function" {
    const range = Range(usize).init(0, 10);
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
    }.square);

    const allocator = std.testing.allocator;

    var results = try std.ArrayList(usize).initCapacity(allocator, 10);
    defer results.deinit(allocator);
    while (it.next()) |v| {
        try results.append(allocator, v);
    }

    const expected = [_]usize{ 0, 4, 16, 36, 64 };
    try std.testing.expectEqualSlices(usize, expected[0..], results.items);
}

test "test array range function" {
    const array = [_]i32{ 1, 2, 3, 4, 5, 6 };
    const arrayRange = ArrayRange(i32).init(&array);
    var it = arrayRange
        .filter(struct {
            fn isEven(x: i32) bool {
                return @mod(x, 2) == 0;
            }
        }.isEven)
        .map(struct {
        fn square(x: i32) i32 {
            return x * x;
        }
    }.square);

    const allocator = std.testing.allocator;

    var results = try std.ArrayList(i32).initCapacity(allocator, 10);
    defer results.deinit(allocator);
    while (it.next()) |v| {
        try results.append(allocator, v);
    }

    const expected = [_]i32{ 4, 16, 36 };
    try std.testing.expectEqualSlices(i32, expected[0..], results.items);
}

test "test find function" {
    const range = Range(usize).init(0, 100);
    const found = range
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
        .find(1600);

    try std.testing.expect(found.? == 1600);
}

test "find inline test" {
    const array = [_]i32{ 10, 20, 30, 40, 50 };
    const arrayRange = ArrayRange(i32).init(&array);
    var it = arrayRange
        .map(struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    const found = it.find(100);
    try std.testing.expect(found.? == 100);

    const not_found = it.find(1234);
    try std.testing.expect(not_found == null);
}

const MyStruct = struct {
    value: i32,
};

fn getValue(s: MyStruct) i32 {
    return s.value;
}

test "custom type range test" {
    const array = [_]MyStruct{
        .{ .value = 1 },
        .{ .value = 2 },
        .{ .value = 3 },
        .{ .value = 4 },
    };
    const arrayRange = ArrayRange(MyStruct).init(&array);
    var it = arrayRange
        .map(getValue);

    const allocator = std.testing.allocator;

    var results = try std.ArrayList(i32).initCapacity(allocator, 10);
    defer results.deinit(allocator);
    while (it.next()) |v| {
        try results.append(allocator, v);
    }

    const expected = [_]i32{ 1, 2, 3, 4 };
    try std.testing.expectEqualSlices(i32, expected[0..], results.items);
}

test "custom type range find test" {
    const array = [_]MyStruct{
        .{ .value = 10 },
        .{ .value = 20 },
        .{ .value = 30 },
        .{ .value = 40 },
    };
    const arrayRange = ArrayRange(MyStruct).init(&array);
    var it = arrayRange
        .map(getValue);

    const found = it.find(30);
    try std.testing.expect(found.? == 30);

    const not_found = it.find(99);
    try std.testing.expect(not_found == null);
}

test "collect function test" {
    const allocator = std.testing.allocator;
    const range = Range(usize).init(0, 20);
    var collected = try range
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
        .collect(allocator);

    defer collected.deinit(allocator);

    const expected = [_]usize{ 0, 4, 16, 36, 64, 100, 144, 196, 256, 324 };
    try std.testing.expectEqualSlices(usize, expected[0..], collected.items);
}

test "fold function test" {
    const range = Range(usize).init(1, 6);
    const sum = range.fold(struct {
        fn add(acc: usize, x: usize) usize {
            return acc + x;
        }
    }.add, @as(usize, 0));

    try std.testing.expect(sum == 15); // 1 + 2 + 3 + 4 + 5 = 15
}

test "fold with array range test" {
    const array = [_]i32{ 1, 2, 3, 4 };
    const arrayRange = ArrayRange(i32).init(&array);
    const product = arrayRange.fold(struct {
        fn multiply(acc: i32, x: i32) i32 {
            return acc * x;
        }
    }.multiply, @as(i32, 1));

    try std.testing.expect(product == 24); // 1 * 2 * 3 * 4 = 24
}

test "count function test" {
    const range = Range(usize).init(0, 10);
    const evenCount = range
        .filter(struct {
            fn isEven(x: usize) bool {
                return x % 2 == 0;
            }
        }.isEven)
        .count();

    try std.testing.expect(evenCount == 5); // 0,2,4,6,8
}

test "any and all function test" {
    const range = Range(usize).init(1, 10);

    const hasEven = range.any(struct {
        fn isEven(x: usize) bool {
            return x % 2 == 0;
        }
    }.isEven);
    try std.testing.expect(hasEven == true);

    const allLessThanTen = range.all(struct {
        fn isLessThanTen(x: usize) bool {
            return x < 10;
        }
    }.isLessThanTen);
    try std.testing.expect(allLessThanTen == true);
}

test "any function with array range" {
    const array = [_]i32{ 1, 3, 5, 7, 8 };
    const arrayRange = ArrayRange(i32).init(&array);

    const hasEven = arrayRange.any(struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven);
    try std.testing.expect(hasEven == true);
}

test "all function with false case" {
    const range = Range(usize).init(1, 10);

    const allLessThanFive = range.all(struct {
        fn isLessThanFive(x: usize) bool {
            return x < 5;
        }
    }.isLessThanFive);
    try std.testing.expect(allLessThanFive == false);
}

test "all function with array range" {
    const array = [_]i32{ 2, 4, 6, 8 };
    const arrayRange = ArrayRange(i32).init(&array);

    const allEven = arrayRange.all(struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven);
    try std.testing.expect(allEven == true);
}

test "collectSlice function test" {
    const allocator = std.testing.allocator;
    const range = Range(usize).init(1, 6);
    const slice = try range
        .filter(struct {
            fn isEven(x: usize) bool {
                return x % 2 == 0;
            }
        }.isEven)
        .collectSlice(allocator);

    defer allocator.free(slice);

    const expected = [_]usize{ 2, 4 };
    try std.testing.expectEqualSlices(usize, expected[0..], slice);
}

test "collectArray function test" {
    const range = Range(usize).init(1, 6);
    const array = try range
        .filter(struct {
            fn isEven(x: usize) bool {
                return x % 2 == 0;
            }
        }.isEven)
        .collectArray(2);

    const expected = [_]usize{ 2, 4 };
    try std.testing.expectEqualSlices(usize, expected[0..], array[0..]);
}

test "collectArray with wrong size returns error" {
    const range = Range(usize).init(1, 6);
    const result = range
        .filter(struct {
            fn isEven(x: usize) bool {
                return x % 2 == 0;
            }
        }.isEven)
        .collectArray(5);

    try std.testing.expectError(error.TooFewElements, result);
}

test "ArrayRange works with ArrayList.items" {
    const allocator = std.testing.allocator;
    var list = try std.ArrayList(i32).initCapacity(allocator, 5);
    defer list.deinit(allocator);

    try list.append(allocator, 10);
    try list.append(allocator, 20);
    try list.append(allocator, 30);
    try list.append(allocator, 40);
    try list.append(allocator, 50);

    // Use ArrayRange on ArrayList.items slice
    var iter = ArrayRange(i32).init(list.items)
        .filter(struct {
            fn isEven(x: i32) bool {
                return @mod(x, 2) == 0;
            }
        }.isEven)
        .map(struct {
        fn half(x: i32) i32 {
            return @divTrunc(x, 2);
        }
    }.half);

    // Use collect() to gather results into an ArrayList
    var results = try iter.collect(allocator);
    defer results.deinit(allocator);

    const expected = [_]i32{ 5, 10, 15, 20, 25 };
    try std.testing.expectEqualSlices(i32, expected[0..], results.items);
}

test "ArrayRange works with static array" {
    const array = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = ArrayRange(i32).init(&array);

    const sum = iter.fold(struct {
        fn add(acc: i32, x: i32) i32 {
            return acc + x;
        }
    }.add, @as(i32, 0));

    try std.testing.expect(sum == 15);
}

// ============================================================================
// Sort Tests
// ============================================================================

test "sorted with Range - ascending integers" {
    const allocator = std.testing.allocator;

    // Create unsorted range with filter (removes evens, keeps odds)
    var result = try Range(i32).init(10, 1) // Intentionally descending
        .sorted(allocator);
    defer result.deinit(allocator);

    // Should be empty because start > end
    try std.testing.expectEqual(@as(usize, 0), result.items.len);

    // Try actual sorting
    var sorted_result = try Range(i32).init(1, 10)
        .sorted(allocator);
    defer sorted_result.deinit(allocator);

    const expected = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    try std.testing.expectEqualSlices(i32, expected[0..], sorted_result.items);
}

test "sorted with ArrayRange - unsorted array" {
    const allocator = std.testing.allocator;
    const array = [_]i32{ 5, 2, 8, 1, 9, 3, 7, 4, 6 };

    var result = try ArrayRange(i32).init(&array)
        .sorted(allocator);
    defer result.deinit(allocator);

    const expected = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    try std.testing.expectEqualSlices(i32, expected[0..], result.items);
}

test "sorted with filter and map - complex chain" {
    const allocator = std.testing.allocator;
    const array = [_]i32{ 10, 3, 7, 1, 9, 4, 2, 8, 5, 6 };

    // Filter odds, square them, then sort
    var result = try ArrayRange(i32).init(&array)
        .filter(struct {
            fn isOdd(x: i32) bool {
                return @mod(x, 2) != 0;
            }
        }.isOdd)
        .map(struct {
            fn square(x: i32) i32 {
                return x * x;
            }
        }.square)
        .sorted(allocator);
    defer result.deinit(allocator);

    // Odds: 3,7,1,9,5 -> squared: 9,49,1,81,25 -> sorted: 1,9,25,49,81
    const expected = [_]i32{ 1, 9, 25, 49, 81 };
    try std.testing.expectEqualSlices(i32, expected[0..], result.items);
}

test "sortedSlice with negative numbers" {
    const allocator = std.testing.allocator;
    const array = [_]i32{ 3, -1, 4, -5, 2, -3, 0 };

    const result = try ArrayRange(i32).init(&array)
        .sortedSlice(allocator);
    defer allocator.free(result);

    const expected = [_]i32{ -5, -3, -1, 0, 2, 3, 4 };
    try std.testing.expectEqualSlices(i32, expected[0..], result);
}

test "sorted with floats" {
    const allocator = std.testing.allocator;
    const array = [_]f32{ 3.14, 1.41, 2.71, 0.5, 4.0, 1.0 };

    var result = try ArrayRange(f32).init(&array)
        .sorted(allocator);
    defer result.deinit(allocator);

    const expected = [_]f32{ 0.5, 1.0, 1.41, 2.71, 3.14, 4.0 };
    try std.testing.expectEqualSlices(f32, expected[0..], result.items);
}

test "sorted preserves duplicates" {
    const allocator = std.testing.allocator;
    const array = [_]i32{ 5, 2, 5, 1, 2, 5, 3 };

    var result = try ArrayRange(i32).init(&array)
        .sorted(allocator);
    defer result.deinit(allocator);

    const expected = [_]i32{ 1, 2, 2, 3, 5, 5, 5 };
    try std.testing.expectEqualSlices(i32, expected[0..], result.items);
}

test "sorted with empty range" {
    const allocator = std.testing.allocator;

    var result = try Range(i32).init(0, 0)
        .sorted(allocator);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), result.items.len);
}

test "sorted with single element" {
    const allocator = std.testing.allocator;
    const array = [_]i32{42};

    var result = try ArrayRange(i32).init(&array)
        .sorted(allocator);
    defer result.deinit(allocator);

    const expected = [_]i32{42};
    try std.testing.expectEqualSlices(i32, expected[0..], result.items);
}

test "sorted performance with large range" {
    const allocator = std.testing.allocator;

    // Create a large range and sort it (already sorted, but tests performance)
    var result = try Range(i32).init(0, 1000)
        .sorted(allocator);
    defer result.deinit(allocator);

    // Verify first and last elements
    try std.testing.expectEqual(@as(i32, 0), result.items[0]);
    try std.testing.expectEqual(@as(i32, 999), result.items[999]);
    try std.testing.expectEqual(@as(usize, 1000), result.items.len);
}

// ============================================================================
// Custom Type Sorting Tests
// ============================================================================

const Person = struct {
    name: []const u8,
    age: u32,

    fn compareByAge(a: Person, b: Person) bool {
        return a.age < b.age;
    }

    fn compareByName(a: Person, b: Person) bool {
        return std.mem.order(u8, a.name, b.name) == .lt;
    }
};

test "sortedBy with custom struct - sort by age" {
    const allocator = std.testing.allocator;

    const people = [_]Person{
        .{ .name = "Alice", .age = 30 },
        .{ .name = "Bob", .age = 25 },
        .{ .name = "Charlie", .age = 35 },
        .{ .name = "Diana", .age = 20 },
    };

    var result = try ArrayRange(Person).init(&people)
        .sortedBy(allocator, Person.compareByAge);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(u32, 20), result.items[0].age);
    try std.testing.expectEqual(@as(u32, 25), result.items[1].age);
    try std.testing.expectEqual(@as(u32, 30), result.items[2].age);
    try std.testing.expectEqual(@as(u32, 35), result.items[3].age);

    try std.testing.expectEqualStrings("Diana", result.items[0].name);
    try std.testing.expectEqualStrings("Bob", result.items[1].name);
    try std.testing.expectEqualStrings("Alice", result.items[2].name);
    try std.testing.expectEqualStrings("Charlie", result.items[3].name);
}

test "sortedBy with custom struct - sort by name" {
    const allocator = std.testing.allocator;

    const people = [_]Person{
        .{ .name = "Charlie", .age = 35 },
        .{ .name = "Alice", .age = 30 },
        .{ .name = "Diana", .age = 20 },
        .{ .name = "Bob", .age = 25 },
    };

    var result = try ArrayRange(Person).init(&people)
        .sortedBy(allocator, Person.compareByName);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("Alice", result.items[0].name);
    try std.testing.expectEqualStrings("Bob", result.items[1].name);
    try std.testing.expectEqualStrings("Charlie", result.items[2].name);
    try std.testing.expectEqualStrings("Diana", result.items[3].name);
}

test "sortedSliceBy with custom comparison" {
    const allocator = std.testing.allocator;

    const people = [_]Person{
        .{ .name = "Alice", .age = 30 },
        .{ .name = "Bob", .age = 25 },
        .{ .name = "Charlie", .age = 35 },
    };

    const result = try ArrayRange(Person).init(&people)
        .sortedSliceBy(allocator, Person.compareByAge);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(u32, 25), result[0].age);
    try std.testing.expectEqual(@as(u32, 30), result[1].age);
    try std.testing.expectEqual(@as(u32, 35), result[2].age);
}

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

test "sortedBy with points - distance from origin" {
    const allocator = std.testing.allocator;

    const points = [_]Point{
        .{ .x = 3, .y = 4 }, // distance: 25
        .{ .x = 1, .y = 1 }, // distance: 2
        .{ .x = 5, .y = 0 }, // distance: 25
        .{ .x = 2, .y = 2 }, // distance: 8
    };

    var result = try ArrayRange(Point).init(&points)
        .sortedBy(allocator, Point.compareByDistance);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(i32, 2), result.items[0].distanceFromOrigin());
    try std.testing.expectEqual(@as(i32, 8), result.items[1].distanceFromOrigin());
    try std.testing.expectEqual(@as(i32, 25), result.items[2].distanceFromOrigin());
    try std.testing.expectEqual(@as(i32, 25), result.items[3].distanceFromOrigin());
}

test "sortedBy with filter and map - complex chain with custom type" {
    const allocator = std.testing.allocator;

    const people = [_]Person{
        .{ .name = "Alice", .age = 30 },
        .{ .name = "Bob", .age = 17 },
        .{ .name = "Charlie", .age = 35 },
        .{ .name = "Diana", .age = 19 },
        .{ .name = "Eve", .age = 40 },
    };

    // Filter adults (age >= 18), map to ages, then sort
    var result = try ArrayRange(Person).init(&people)
        .filter(struct {
            fn isAdult(p: Person) bool {
                return p.age >= 18;
            }
        }.isAdult)
        .map(struct {
            fn getAge(p: Person) u32 {
                return p.age;
            }
        }.getAge)
        .sorted(allocator);
    defer result.deinit(allocator);

    const expected = [_]u32{ 19, 30, 35, 40 };
    try std.testing.expectEqualSlices(u32, expected[0..], result.items);
}

test "sortedBy with descending order" {
    const allocator = std.testing.allocator;

    const compareDesc = struct {
        fn f(a: i32, b: i32) bool {
            return a > b; // Reverse comparison for descending order
        }
    }.f;

    const array = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6 };
    var result = try ArrayRange(i32).init(&array)
        .sortedBy(allocator, compareDesc);
    defer result.deinit(allocator);

    const expected = [_]i32{ 9, 6, 5, 4, 3, 2, 1, 1 };
    try std.testing.expectEqualSlices(i32, expected[0..], result.items);
}

test "sortedWith with context - sort indices by external scores" {
    const allocator = std.testing.allocator;

    // Real use case: sort indices based on scores in a separate array
    const scores = [_]u32{ 85, 92, 78, 95, 88 };
    const indices = [_]usize{ 0, 1, 2, 3, 4 };

    const SortContext = struct {
        scores: []const u32,

        fn compareByScore(ctx: @This(), a: usize, b: usize) bool {
            return ctx.scores[a] < ctx.scores[b];
        }
    };

    const ctx = SortContext{ .scores = &scores };
    var result = try ArrayRange(usize).init(&indices)
        .sortedWith(allocator, SortContext.compareByScore, ctx);
    defer result.deinit(allocator);

    // Indices sorted by their corresponding scores: 78, 85, 88, 92, 95
    const expected = [_]usize{ 2, 0, 4, 1, 3 };
    try std.testing.expectEqualSlices(usize, expected[0..], result.items);

    // Verify the scores are in ascending order when accessed via sorted indices
    try std.testing.expect(scores[result.items[0]] < scores[result.items[1]]);
    try std.testing.expect(scores[result.items[1]] < scores[result.items[2]]);
    try std.testing.expect(scores[result.items[2]] < scores[result.items[3]]);
    try std.testing.expect(scores[result.items[3]] < scores[result.items[4]]);
}
