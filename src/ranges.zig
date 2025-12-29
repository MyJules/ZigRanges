const std = @import("std");

/// --- Helper Functions ---
fn getFnInfo(comptime F: anytype) @TypeOf(@typeInfo(@TypeOf(F)).@"fn") {
    const ti = @typeInfo(@TypeOf(F));
    if (ti != .@"fn") @compileError("expected function");
    return ti.@"fn";
}

/// --- Iterator Mixin ---
/// Generates common iterator operations for any type with a next() method
fn IteratorOps(comptime T: type) type {
    return struct {
        pub fn map(self: anytype, comptime F: anytype) MapIterator(@TypeOf(self.*), F) {
            return MapIterator(@TypeOf(self.*), F).init(self.*);
        }

        pub fn filter(self: anytype, comptime P: anytype) FilterIterator(@TypeOf(self.*), P) {
            return FilterIterator(@TypeOf(self.*), P).init(self.*);
        }

        pub fn find(self: anytype, value: T) ?T {
            var iter = self.*;
            while (iter.next()) |v| {
                if (eq(T, value, v)) return v;
            }
            return null;
        }

        pub fn collect(self: anytype, allocator: std.mem.Allocator) !std.ArrayList(T) {
            var results = try std.ArrayList(T).initCapacity(allocator, 0);
            var iter = self.*;
            while (iter.next()) |v| {
                try results.append(allocator, v);
            }
            return results;
        }

        /// Collect into a slice (caller owns memory)
        pub fn collectSlice(self: anytype, allocator: std.mem.Allocator) ![]T {
            var list = try self.collect(allocator);
            defer list.deinit(allocator);
            return list.toOwnedSlice(allocator);
        }

        /// Collect into a fixed-size array, returns error if iterator has more/fewer elements
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

        pub fn count(self: anytype) usize {
            var cnt: usize = 0;
            var iter = self.*;
            while (iter.next()) |_| cnt += 1;
            return cnt;
        }

        pub fn any(self: anytype, comptime P: anytype) bool {
            var iter = self.*;
            while (iter.next()) |v| if (P(v)) return true;
            return false;
        }

        pub fn all(self: anytype, comptime P: anytype) bool {
            var iter = self.*;
            while (iter.next()) |v| if (!P(v)) return false;
            return true;
        }

        pub fn fold(self: anytype, comptime F: anytype, initial: anytype) @TypeOf(initial) {
            var acc = initial;
            var iter = self.*;
            while (iter.next()) |v| acc = F(acc, v);
            return acc;
        }
    };
}

/// --- ArrayRange Iterator ---
pub fn ArrayRange(comptime T: type) type {
    return struct {
        arr: []const T,
        index: usize,

        const Ops = IteratorOps(T);

        pub fn init(arr: []const T) @This() {
            return .{ .arr = arr, .index = 0 };
        }

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
    };
}

/// --- Range Iterator ---
pub fn Range(comptime T: type) type {
    return struct {
        start: T,
        end: T,

        const Ops = IteratorOps(T);

        pub fn init(start: T, end: T) @This() {
            return @This(){ .start = start, .end = end };
        }

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
    };
}

/// --- MapIterator ---
fn MapIterator(comptime Inner: type, comptime F: anytype) type {
    const info = getFnInfo(F);
    const Out = info.return_type.?;

    return struct {
        inner: Inner,

        const Ops = IteratorOps(Out);

        pub fn init(inner: Inner) @This() {
            return .{ .inner = inner };
        }

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
    };
}

/// --- FilterIterator ---
fn FilterIterator(comptime Inner: type, comptime P: anytype) type {
    const info = getFnInfo(P);
    const T = info.params[0].type.?;

    return struct {
        inner: Inner,

        const Ops = IteratorOps(T);

        pub fn init(inner: Inner) @This() {
            return .{ .inner = inner };
        }

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
    };
}

fn eq(comptime T: type, a: T, b: T) bool {
    const info = @typeInfo(T);

    switch (info) {
        // Primitive numeric types
        .int, .float, .bool, .enum_literal => return a == b,

        // Structs: compare field by field
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

// Tests

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
