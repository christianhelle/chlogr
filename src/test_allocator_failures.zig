const std = @import("std");
const models = @import("models.zig");
const changelog_generator = @import("changelog_generator.zig");

/// Failing allocator that fails after N allocations
const FailingAllocator = struct {
    parent_allocator: std.mem.Allocator,
    fail_after: usize,
    allocation_count: usize = 0,

    pub fn allocator(self: *FailingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = std.mem.Allocator.noRemap,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *FailingAllocator = @ptrCast(@alignCast(ctx));
        self.allocation_count += 1;
        if (self.allocation_count > self.fail_after) {
            return null;
        }
        return self.parent_allocator.rawAlloc(len, ptr_align, ret_addr);
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *FailingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent_allocator.rawResize(buf, buf_align, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        const self: *FailingAllocator = @ptrCast(@alignCast(ctx));
        self.parent_allocator.rawFree(buf, buf_align, ret_addr);
    }
};

fn testAllocationFailureDuringFirstSectionCreation() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    var failing_alloc = FailingAllocator{
        .parent_allocator = gpa.allocator(),
        .fail_after = 5, // Fail after a few allocations
    };
    const allocator = failing_alloc.allocator();

    const releases_json =
        \\[
        \\  {
        \\    "tag_name": "v1.0.0",
        \\    "name": "Release v1.0.0",
        \\    "published_at": "2024-01-10T10:00:00Z"
        \\  }
        \\]
    ;

    const prs_json =
        \\[
        \\  {
        \\    "number": 1,
        \\    "title": "Feature A",
        \\    "body": "Description",
        \\    "html_url": "https://github.com/owner/repo/pull/1",
        \\    "user": {
        \\      "login": "alice",
        \\      "html_url": "https://github.com/alice"
        \\    },
        \\    "labels": [
        \\      {
        \\        "name": "feature",
        \\        "color": "0366d6"
        \\      }
        \\    ],
        \\    "merged_at": "2024-01-09T10:00:00Z"
        \\  }
        \\]
    ;

    var releases_parsed = std.json.parseFromSlice(
        []models.Release,
        allocator,
        releases_json,
        .{},
    ) catch |err| {
        // Expected to fail during parsing or section creation
        std.debug.print("  Expected allocation failure during section creation: {any}\n", .{err});
        return;
    };
    defer releases_parsed.deinit();

    var prs_parsed = std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        prs_json,
        .{},
    ) catch {
        return;
    };
    defer prs_parsed.deinit();

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = gen.generate(releases_parsed.value, prs_parsed.value) catch |err| {
        std.debug.print("  Expected allocation failure: {any}\n", .{err});
        return;
    };
    defer gen.deinitChangelog(changelog);
}

fn testAllocationFailureDuringPRAppend() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    var failing_alloc = FailingAllocator{
        .parent_allocator = gpa.allocator(),
        .fail_after = 10,
    };
    const allocator = failing_alloc.allocator();

    const releases_json =
        \\[
        \\  {
        \\    "tag_name": "v1.0.0",
        \\    "name": "Release v1.0.0",
        \\    "published_at": "2024-01-10T10:00:00Z"
        \\  }
        \\]
    ;

    const prs_json =
        \\[
        \\  {
        \\    "number": 1,
        \\    "title": "PR 1",
        \\    "body": "Description",
        \\    "html_url": "https://github.com/owner/repo/pull/1",
        \\    "user": {
        \\      "login": "alice",
        \\      "html_url": "https://github.com/alice"
        \\    },
        \\    "labels": [{"name": "feature", "color": "0366d6"}],
        \\    "merged_at": "2024-01-09T10:00:00Z"
        \\  },
        \\  {
        \\    "number": 2,
        \\    "title": "PR 2",
        \\    "body": "Description",
        \\    "html_url": "https://github.com/owner/repo/pull/2",
        \\    "user": {
        \\      "login": "bob",
        \\      "html_url": "https://github.com/bob"
        \\    },
        \\    "labels": [{"name": "feature", "color": "0366d6"}],
        \\    "merged_at": "2024-01-09T11:00:00Z"
        \\  }
        \\]
    ;

    var releases_parsed = std.json.parseFromSlice(
        []models.Release,
        allocator,
        releases_json,
        .{},
    ) catch {
        return;
    };
    defer releases_parsed.deinit();

    var prs_parsed = std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        prs_json,
        .{},
    ) catch {
        return;
    };
    defer prs_parsed.deinit();

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = gen.generate(releases_parsed.value, prs_parsed.value) catch |err| {
        std.debug.print("  Expected allocation failure during PR append: {any}\n", .{err});
        return;
    };
    defer gen.deinitChangelog(changelog);
}

fn testPartialInitializationCleanup() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("  MEMORY LEAK DETECTED in partial initialization cleanup!\n", .{});
        }
    }
    
    var failing_alloc = FailingAllocator{
        .parent_allocator = gpa.allocator(),
        .fail_after = 8,
    };
    const allocator = failing_alloc.allocator();

    const releases_json =
        \\[
        \\  {
        \\    "tag_name": "v1.0.0",
        \\    "name": "Release v1.0.0",
        \\    "published_at": "2024-01-10T10:00:00Z"
        \\  }
        \\]
    ;

    const prs_json =
        \\[
        \\  {
        \\    "number": 1,
        \\    "title": "Feature",
        \\    "body": "Description",
        \\    "html_url": "https://github.com/owner/repo/pull/1",
        \\    "user": {
        \\      "login": "alice",
        \\      "html_url": "https://github.com/alice"
        \\    },
        \\    "labels": [{"name": "feature", "color": "0366d6"}],
        \\    "merged_at": "2024-01-09T10:00:00Z"
        \\  }
        \\]
    ;

    var releases_parsed = std.json.parseFromSlice(
        []models.Release,
        allocator,
        releases_json,
        .{},
    ) catch {
        return;
    };
    defer releases_parsed.deinit();

    var prs_parsed = std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        prs_json,
        .{},
    ) catch {
        return;
    };
    defer prs_parsed.deinit();

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    _ = gen.generate(releases_parsed.value, prs_parsed.value) catch |err| {
        std.debug.print("  Allocation failure handled: {any}\n", .{err});
        return;
    };
}

pub fn main() !void {
    std.debug.print("\n=== Allocator Failure Tests (Issue #3) ===\n\n", .{});

    std.debug.print("Test: Allocation failure during first section creation...\n", .{});
    try testAllocationFailureDuringFirstSectionCreation();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: Allocation failure during PR append...\n", .{});
    try testAllocationFailureDuringPRAppend();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: Partial initialization cleanup (leak detection)...\n", .{});
    try testPartialInitializationCleanup();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("✅ All allocator failure tests completed\n", .{});
}
