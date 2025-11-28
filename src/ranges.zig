const std = @import("std");
const ranges_test = @import("ranges_test.zig");

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

        pub fn map(self: *const @This(), comptime F: anytype) MapIterator(@This(), F) {
            return MapIterator(@This(), F).init(self.*);
        }

        pub fn filter(self: *const @This(), comptime P: anytype) FilterIterator(@This(), P) {
            return FilterIterator(@This(), P).init(self.*);
        }

        pub fn find(self: *const @This(), value: T) ?T {
            var iter = self.*;
            while (iter.next()) |v| {
                if (eq(T, value, v)) return v;
            }
            return null;
        }
    };
}

pub fn Range(comptime T: type) type {
    return struct {
        start: T,
        end: T,

        pub fn init(start: usize, end: usize) @This() {
            return @This(){
                .start = start,
                .end = end,
            };
        }

        pub fn next(self: *@This()) ?usize {
            if (self.start >= self.end) return null;
            const v = self.start;
            self.start += 1;
            return v;
        }

        fn nextAdapter(ctx: *anyopaque) ?usize {
            const p: *@This() = @ptrCast(@alignCast(@alignOf(ctx)));
            return p.next();
        }

        pub fn map(self: *const @This(), comptime F: anytype) MapIterator(@This(), F) {
            return MapIterator(@This(), F).init(self.*);
        }

        pub fn filter(self: *const @This(), comptime P: anytype) FilterIterator(@This(), P) {
            return FilterIterator(@This(), P).init(self.*);
        }

        pub fn find(self: *const @This(), value: T) ?T {
            var iter = self.*;
            while (iter.next()) |v| {
                if (eq(T, value, v)) return v;
            }
            return null;
        }
    };
}

fn Iterator(comptime T: type) type {
    return struct {
        nextFn: *const fn (ctx: *anyopaque) ?T,
        ctx: *anyopaque,

        pub fn next(self: *@This()) ?T {
            return self.nextFn(self.ctx);
        }
    };
}

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
            while (iter.next()) |v| {
                if (eq(Out, value, v)) return v;
            }
            return null;
        }
    };
}

fn FilterIterator(comptime Inner: type, comptime P: anytype) type {
    const info = getFnInfo(P);
    const T = info.params[0].type.?;

    return struct {
        inner: Inner,

        pub fn init(inner: Inner) @This() {
            return .{ .inner = inner };
        }

        pub fn next(self: *@This()) ?T {
            while (self.inner.next()) |v| {
                if (P(v)) return v;
            }
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
            while (iter.next()) |v| {
                if (eq(T, value, v)) return v;
            }
            return null;
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
