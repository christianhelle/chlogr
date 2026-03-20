const std = @import("std");

pub const VERSION = "0.3.6";

pub const CliArgs = struct {
    repo: ?[]const u8 = null,
    token: ?[]const u8 = null,
    output: []const u8 = "CHANGELOG.md",
    since_tag: ?[]const u8 = null,
    until_tag: ?[]const u8 = null,
    exclude_labels: ?[]const u8 = null,
    parallel: bool = false,
    degree_of_parallelism: u32 = 4,
};

pub const CliParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CliParser {
        return CliParser{
            .allocator = allocator,
        };
    }

    pub fn parse(_: CliParser, args: []const []const u8) !CliArgs {
        var result = CliArgs{};
        var i: usize = 1; // Skip program name

        while (i < args.len) : (i += 1) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "--repo")) {
                i += 1;
                if (i >= args.len) return error.MissingRepoValue;
                result.repo = args[i];
            } else if (std.mem.eql(u8, arg, "--token")) {
                i += 1;
                if (i >= args.len) return error.MissingTokenValue;
                result.token = args[i];
            } else if (std.mem.eql(u8, arg, "--output")) {
                i += 1;
                if (i >= args.len) return error.MissingOutputValue;
                result.output = args[i];
            } else if (std.mem.eql(u8, arg, "--since-tag")) {
                i += 1;
                if (i >= args.len) return error.MissingSinceTagValue;
                result.since_tag = args[i];
            } else if (std.mem.eql(u8, arg, "--until-tag")) {
                i += 1;
                if (i >= args.len) return error.MissingUntilTagValue;
                result.until_tag = args[i];
            } else if (std.mem.eql(u8, arg, "--exclude-labels")) {
                i += 1;
                if (i >= args.len) return error.MissingExcludeLabelsValue;
                result.exclude_labels = args[i];
            } else if (std.mem.eql(u8, arg, "--parallel")) {
                i += 1;
                if (i >= args.len) return error.MissingParallelValue;
                result.parallel = true;
                result.degree_of_parallelism = std.fmt.parseInt(
                    u32,
                    args[i],
                    10,
                ) catch {
                    std.debug.print(
                        "Invalid value for --parallel: {s} (must be a positive integer)\n",
                        .{args[i]},
                    );
                    return error.InvalidParallelValue;
                };
                if (result.degree_of_parallelism == 0) {
                    std.debug.print(
                        "Invalid value for --parallel: {s} (must be at least 1)\n",
                        .{args[i]},
                    );
                    return error.InvalidParallelValue;
                }
            } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                return error.HelpRequested;
            } else {
                std.debug.print("Unknown argument: {s}\n", .{arg});
                return error.UnknownArgument;
            }
        }

        return result;
    }

    pub fn printHelp(self: CliParser) !void {
        const text =
            \\GitHub Changelog Generator v{s}
            \\
            \\Usage: chlogr --repo <[org|user]/[repo]> [options]
            \\
            \\Required:
            \\  --repo <[org|user]/[repo]>  GitHub repository (e.g., github/cli)
            \\
            \\Options:
            \\  --token <token>          GitHub API token (falls back to env vars or gh CLI)
            \\  --output <path>          Output file (default: CHANGELOG.md)
            \\  --since-tag <tag>        Start from this tag/version
            \\  --until-tag <tag>       End at this tag/version
            \\  --exclude-labels <csv>   Comma-separated labels to exclude
            \\  --parallel <N>           Fetch with up to N concurrent page requests (default: 4)
            \\  --help, -h               Show this help message
            \\
            \\Examples:
            \\  chlogr --repo github/cli
            \\  chlogr --repo github/cli --token ghp_xxxx --output HISTORY.md
            \\
        ;
        const help_text = try std.fmt.allocPrint(self.allocator, text, .{VERSION});
        defer self.allocator.free(help_text);
        std.debug.print("{s}", .{help_text});
    }
};

// CLI Parsing Tests

test "parse --parallel flag present" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--parallel", "4" };
    const result = try parser.parse(&args);

    try std.testing.expect(result.parallel == true);
    try std.testing.expect(result.degree_of_parallelism == 4);
}

test "parse --parallel flag absent" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--repo", "owner/repo" };
    const result = try parser.parse(&args);

    try std.testing.expect(result.parallel == false);
}

test "parse --repo argument" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--repo", "owner/repo" };
    const result = try parser.parse(&args);

    try std.testing.expect(result.repo != null);
    try std.testing.expectEqualStrings("owner/repo", result.repo.?);
}

test "parse --output argument" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--output", "HISTORY.md" };
    const result = try parser.parse(&args);

    try std.testing.expectEqualStrings("HISTORY.md", result.output);
}

test "parse --since-tag argument" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--since-tag", "v1.0.0" };
    const result = try parser.parse(&args);

    try std.testing.expect(result.since_tag != null);
    try std.testing.expectEqualStrings("v1.0.0", result.since_tag.?);
}

test "parse --until-tag argument" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--until-tag", "v2.0.0" };
    const result = try parser.parse(&args);

    try std.testing.expect(result.until_tag != null);
    try std.testing.expectEqualStrings("v2.0.0", result.until_tag.?);
}

test "parse --exclude-labels argument" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--exclude-labels", "bug,wip" };
    const result = try parser.parse(&args);

    try std.testing.expect(result.exclude_labels != null);
    try std.testing.expectEqualStrings("bug,wip", result.exclude_labels.?);
}

test "parse --help returns HelpRequested error" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--help" };
    const result = parser.parse(&args);

    try std.testing.expectError(error.HelpRequested, result);
}

test "parse unknown argument returns UnknownArgument error" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--unknown" };
    const result = parser.parse(&args);

    try std.testing.expectError(error.UnknownArgument, result);
}

test "parse --parallel combined with --repo and --output" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--parallel", "8", "--repo", "owner/repo", "--output", "HISTORY.md" };
    const result = try parser.parse(&args);

    try std.testing.expect(result.parallel == true);
    try std.testing.expect(result.degree_of_parallelism == 8);
    try std.testing.expect(result.repo != null);
    try std.testing.expectEqualStrings("owner/repo", result.repo.?);
    try std.testing.expectEqualStrings("HISTORY.md", result.output);
}

test "parse --parallel with zero returns error" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--parallel", "0" };
    const result = parser.parse(&args);

    try std.testing.expectError(error.InvalidParallelValue, result);
}

test "parse --parallel 1" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--parallel", "1" };
    const result = try parser.parse(&args);

    try std.testing.expect(result.parallel == true);
    try std.testing.expect(result.degree_of_parallelism == 1);
}

test "parse --parallel 32" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--parallel", "32" };
    const result = try parser.parse(&args);

    try std.testing.expect(result.parallel == true);
    try std.testing.expect(result.degree_of_parallelism == 32);
}

test "parse --parallel 64" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--parallel", "64" };
    const result = try parser.parse(&args);

    try std.testing.expect(result.parallel == true);
    try std.testing.expect(result.degree_of_parallelism == 64);
}

test "parse --parallel with missing value" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--parallel" };
    const result = parser.parse(&args);

    try std.testing.expectError(error.MissingParallelValue, result);
}

test "parse --parallel with invalid value" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--parallel", "abc" };
    const result = parser.parse(&args);

    try std.testing.expectError(error.InvalidParallelValue, result);
}

test "parse --repo owner/repo --parallel 10" {
    const allocator = std.testing.allocator;
    const parser = CliParser.init(allocator);

    const args = [_][]const u8{ "chlogr", "--repo", "owner/repo", "--parallel", "10" };
    const result = try parser.parse(&args);

    try std.testing.expect(result.parallel == true);
    try std.testing.expect(result.degree_of_parallelism == 10);
    try std.testing.expect(result.repo != null);
    try std.testing.expectEqualStrings("owner/repo", result.repo.?);
}
