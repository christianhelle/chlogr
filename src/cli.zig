const std = @import("std");

pub const VERSION = "0.2.5";

pub const CliArgs = struct {
    repo: ?[]const u8 = null,
    token: ?[]const u8 = null,
    output: []const u8 = "CHANGELOG.md",
    since_tag: ?[]const u8 = null,
    until_tag: ?[]const u8 = null,
    exclude_labels: ?[]const u8 = null,
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
