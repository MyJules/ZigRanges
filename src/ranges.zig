const std = @import("std");

//
// Generic erased iterator
//
pub fn Iterator(comptime T: type) type {
    return struct {
        nextFn: *const fn (ctx: *anyopaque) ?T,
        ctx: *anyopaque,

        pub fn next(self: *@This()) ?T {
            return self.nextFn(self.ctx);
        }
    };
}

//
// TypeInfo helper
//
fn getFnInfo(comptime F: anytype) @TypeOf(@typeInfo(@TypeOf(F)).@"fn") {
    const ti = @typeInfo(@TypeOf(F));
    if (ti != .@"fn") @compileError("expected function");
    return ti.@"fn";
}

//
// Range iterator
//
pub fn range(start: usize, end: usize) Range {
    return Range{ .start = start, .end = end };
}

pub const Range = struct {
    start: usize,
    end: usize,

    fn nextRaw(self: *Range) ?usize {
        if (self.start >= self.end) return null;
        const v = self.start;
        self.start += 1;
        return v;
    }

    pub fn next(self: *@This()) ?usize {
        return self.nextRaw();
    }

    fn nextAdapter(ctx: *anyopaque) ?usize {
        const p: *Range = @ptrCast(@alignCast(@alignOf(ctx)));
        return p.next();
    }

    pub fn toIter(self: *Range) Iterator(usize) {
        return .{ .nextFn = nextAdapter, .ctx = self };
    }

    pub fn map(self: *const Range, comptime F: anytype) MapIterator(Range, F) {
        return MapIterator(Range, F).init(self.*);
    }

    pub fn filter(self: *const Range, comptime P: anytype) FilterIterator(Range, P) {
        return FilterIterator(Range, P).init(self.*);
    }
};

//
// Map iterator
//
pub fn MapIterator(comptime Inner: type, comptime F: anytype) type {
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
    };
}

//
// Filter iterator
//
pub fn FilterIterator(comptime Inner: type, comptime P: anytype) type {
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
    };
}

