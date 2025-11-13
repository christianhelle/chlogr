const std = @import("std");
const cli = @import("cli.zig");
const token_resolver = @import("token_resolver.zig");
const github_api = @import("github_api.zig");
const models = @import("models.zig");
const changelog_generator = @import("changelog_generator.zig");
const markdown_formatter = @import("markdown_formatter.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Parse CLI arguments
    const cli_parser = cli.CliParser.init(allocator);
    const parsed_args = cli_parser.parse(args) catch |err| {
        if (err == error.HelpRequested) {
            cli.CliParser.printHelp();
            return;
        }
        std.debug.print("Error: {}\n", .{err});
        cli.CliParser.printHelp();
        return err;
    };

    // Validate required arguments
    if (parsed_args.owner == null or parsed_args.repo == null) {
        std.debug.print("Error: --owner and --repo are required\n\n", .{});
        cli.CliParser.printHelp();
        return error.MissingRequiredArgs;
    }

    // Resolve GitHub token
    const resolver = token_resolver.TokenResolver.init(allocator);
    const token = resolver.resolve(parsed_args.token) catch |err| {
        std.debug.print("Error: Could not retrieve GitHub token\n", .{});
        std.debug.print("  Tried: --token flag, GITHUB_TOKEN env var, GH_TOKEN env var, gh CLI\n", .{});
        std.debug.print("  Details: {}\n", .{err});
        return err;
    };
    defer resolver.deinit(token);

    // Initialize GitHub API client
    var api_client = github_api.GitHubApiClient.init(allocator, token, parsed_args.owner.?, parsed_args.repo.?);
    defer api_client.deinit();

    std.debug.print("GitHub Changelog Generator v0.1.0\n", .{});
    std.debug.print("Owner: {s}\n", .{parsed_args.owner.?});
    std.debug.print("Repo: {s}\n", .{parsed_args.repo.?});
    std.debug.print("Output: {s}\n", .{parsed_args.output});
    std.debug.print("\nFetching data from GitHub...\n", .{});

    // Fetch releases and PRs
    const releases = api_client.getReleases() catch |err| {
        std.debug.print("Error fetching releases: {}\n", .{err});
        return err;
    };
    defer allocator.free(releases);

    const prs = api_client.getMergedPullRequests(100) catch |err| {
        std.debug.print("Error fetching pull requests: {}\n", .{err});
        return err;
    };
    defer allocator.free(prs);

    std.debug.print("Found {d} releases and {d} pull requests\n", .{ releases.len, prs.len });

    // Generate changelog
    var gen = changelog_generator.ChangelogGenerator.init(allocator, parsed_args.exclude_labels);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinit(changelog);

    // Format to Markdown
    var formatter = markdown_formatter.MarkdownFormatter.init(allocator);
    const markdown = try formatter.format(changelog);
    defer formatter.deinit(markdown);

    // Write to file
    try formatter.writeToFile(parsed_args.output, markdown);

    std.debug.print("Changelog written to {s}\n", .{parsed_args.output});
}

