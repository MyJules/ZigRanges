const std = @import("std");

/// --- ArrayRange Iterator ---
pub fn ArrayRange(comptime T: type) type {
    return struct {
        arr: []const T,
        index: usize,

        pub fn init(arr: []const T) @This() {
            return .{ .arr = arr, .index = 0 };
        }

        pub fn next(self: *@This()) ?T {
            if (self.index >= self.arr.len) return null;
            const v = self.arr[self.index];
            self.index += 1;
            return v;
        }

        // --- Transformations ---
        pub fn map(self: *const @This(), comptime F: anytype) MapIterator(@This(), F) {
            return MapIterator(@This(), F).init(self.*);
        }

        pub fn filter(self: *const @This(), comptime P: anytype) FilterIterator(@This(), P) {
            return FilterIterator(@This(), P).init(self.*);
        }

        // --- Queries ---
        pub fn find(self: *const @This(), value: T) ?T {
            var iter = self.*;
            while (iter.next()) |v| {
                if (eq(T, value, v)) return v;
            }
            return null;
        }

        pub fn collect(self: *const @This(), allocator: std.mem.Allocator) !std.ArrayList(T) {
            var results = try std.ArrayList(T).initCapacity(allocator, self.arr.len);
            var iter = self.*;
            while (iter.next()) |v| {
                try results.append(allocator, v);
            }
            return results;
        }

        pub fn count(self: *const @This()) usize {
            var cnt: usize = 0;
            var iter = self.*;
            while (iter.next()) |_| cnt += 1;
            return cnt;
        }

        pub fn any(self: *const @This(), comptime P: anytype) bool {
            var iter = self.*;
            while (iter.next()) |v| if (P(v)) return true;
            return false;
        }

        pub fn all(self: *const @This(), comptime P: anytype) bool {
            var iter = self.*;
            while (iter.next()) |v| if (!P(v)) return false;
            return true;
        }

        pub fn fold(self: *const @This(), comptime F: anytype, initial: anytype) @TypeOf(initial) {
            var acc = initial;
            var iter = self.*;
            while (iter.next()) |v| acc = F(acc, v);
            return acc;
        }
    };
}

/// --- Range Iterator ---
pub fn Range(comptime T: type) type {
    return struct {
        start: T,
        end: T,

        pub fn init(start: T, end: T) @This() {
            return @This(){ .start = start, .end = end };
        }

        pub fn next(self: *@This()) ?T {
            if (self.start >= self.end) return null;
            const v = self.start;
            self.start += 1;
            return v;
        }

        pub fn map(self: *const @This(), comptime F: anytype) MapIterator(@This(), F) {
            return MapIterator(@This(), F).init(self.*);
        }

        pub fn filter(self: *const @This(), comptime P: anytype) FilterIterator(@This(), P) {
            return FilterIterator(@This(), P).init(self.*);
        }

        pub fn find(self: *const @This(), value: T) ?T {
            var iter = self.*;
            while (iter.next()) |v| if (eq(T, value, v)) return v;
            return null;
        }

        pub fn collect(self: *const @This(), allocator: std.mem.Allocator) !std.ArrayList(T) {
            var results = try std.ArrayList(T).initCapacity(allocator, self.end - self.start);
            var iter = self.*;
            while (iter.next()) |v| try results.append(allocator, v);
            return results;
        }

        pub fn count(self: *const @This()) usize {
            var cnt: usize = 0;
            var iter = self.*;
            while (iter.next()) |_| cnt += 1;
            return cnt;
        }

        pub fn any(self: *const @This(), comptime P: anytype) bool {
            var iter = self.*;
            while (iter.next()) |v| if (P(v)) return true;
            return false;
        }

        pub fn all(self: *const @This(), comptime P: anytype) bool {
            var iter = self.*;
            while (iter.next()) |v| if (!P(v)) return false;
            return true;
        }

        pub fn fold(self: *const @This(), comptime F: anytype, initial: anytype) @TypeOf(initial) {
            var acc = initial;
            var iter = self.*;
            while (iter.next()) |v| acc = F(acc, v);
            return acc;
        }
    };
}

/// --- MapIterator ---
fn getFnInfo(comptime F: anytype) @TypeOf(@typeInfo(@TypeOf(F)).@"fn") {
    const ti = @typeInfo(@TypeOf(F));
    if (ti != .@"fn") @compileError("expected function");
    return ti.@"fn";
}

fn MapIterator(comptime Inner: type, comptime F: anytype) type {
    const info = getFnInfo(F);
    const Out = info.return_type.?;

    return struct {
        inner: Inner,

        pub fn init(inner: Inner) @This() {
            return .{ .inner = inner };
        }

        pub fn next(self: *@This()) ?Out {
            const v = self.inner.next() orelse return null;
            return F(v);
        }

        pub fn map(self: *const @This(), comptime G: anytype) MapIterator(@This(), G) {
            return MapIterator(@This(), G).init(self.*);
        }

        pub fn filter(self: *const @This(), comptime P: anytype) FilterIterator(@This(), P) {
            return FilterIterator(@This(), P).init(self.*);
        }

        pub fn find(self: *const @This(), value: Out) ?Out {
            var iter = self.*;
            while (iter.next()) |v| if (eq(Out, value, v)) return v;
            return null;
        }

        pub fn collect(self: *const @This(), allocator: std.mem.Allocator) !std.ArrayList(Out) {
            var results = try std.ArrayList(Out).initCapacity(allocator, 0);
            var iter = self.*;
            while (iter.next()) |v| try results.append(allocator, v);
            return results;
        }

        pub fn count(self: *const @This()) usize {
            var cnt: usize = 0;
            var iter = self.*;
            while (iter.next()) |_| cnt += 1;
            return cnt;
        }

        pub fn any(self: *const @This(), comptime P2: anytype) bool {
            var iter = self.*;
            while (iter.next()) |v| if (P2(v)) return true;
            return false;
        }

        pub fn all(self: *const @This(), comptime P2: anytype) bool {
            var iter = self.*;
            while (iter.next()) |v| if (!P2(v)) return false;
            return true;
        }

        pub fn fold(self: *const @This(), comptime F2: anytype, initial: anytype) initial {
            var acc = initial;
            var iter = self.*;
            while (iter.next()) |v| acc = F2(acc, v);
            return acc;
        }
    };
}

/// --- FilterIterator ---
fn FilterIterator(comptime Inner: type, comptime P: anytype) type {
    const info = getFnInfo(P);
    const T = info.params[0].type.?;

    return struct {
        inner: Inner,

        pub fn init(inner: Inner) @This() {
            return .{ .inner = inner };
        }

        pub fn next(self: *@This()) ?T {
            while (self.inner.next()) |v| if (P(v)) return v;
            return null;
        }

        pub fn map(self: *const @This(), comptime F: anytype) MapIterator(@This(), F) {
            return MapIterator(@This(), F).init(self.*);
        }

        pub fn filter(self: *const @This(), comptime P2: anytype) FilterIterator(@This(), P2) {
            return FilterIterator(@This(), P2).init(self.*);
        }

        pub fn find(self: *const @This(), value: T) ?T {
            var iter = self.*;
            while (iter.next()) |v| if (eq(T, value, v)) return v;
            return null;
        }

        pub fn collect(self: *const @This(), allocator: std.mem.Allocator) !std.ArrayList(T) {
            var results = try std.ArrayList(T).initCapacity(allocator, 0);
            var iter = self.*;
            while (iter.next()) |v| try results.append(allocator, v);
            return results;
        }

        pub fn count(self: *const @This()) usize {
            var cnt: usize = 0;
            var iter = self.*;
            while (iter.next()) |_| cnt += 1;
            return cnt;
        }

        pub fn any(self: *const @This(), comptime P2: anytype) bool {
            var iter = self.*;
            while (iter.next()) |v| if (P2(v)) return true;
            return false;
        }

        pub fn all(self: *const @This(), comptime P2: anytype) bool {
            var iter = self.*;
            while (iter.next()) |v| if (!P2(v)) return false;
            return true;
        }

        pub fn fold(self: *const @This(), comptime F2: anytype, initial: anytype) @TypeOf(initial) {
            var acc = initial;
            var iter = self.*;
            while (iter.next()) |v| acc = F2(acc, v);
            return acc;
        }
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

