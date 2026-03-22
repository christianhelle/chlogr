# Changelog Generator

A fast, efficient, native CLI tool to automatically generate changelogs from GitHub tags, merged pull requests, and closed issues. Written in Zig

## Features

- Fast, compiled binary (zero dependencies, pure Zig stdlib)
- Generates Markdown changelogs automatically
- Groups merged pull requests by labels (Features, Bug Fixes, Merged Pull Requests)
- Adds a Closed Issues section under each release based on issue close timestamps
- Links to PRs, issues, and contributors
- Smart token resolution (--token flag → env vars → `gh auth token` CLI)
- Works with any GitHub repository
- Progress output during fetch — per-section headers and page counters keep you informed on large repos
- Optional parallel fetching (`--parallel <N>`) — fetches releases, PRs, and closed issues concurrently; release and PR pagination use bounded page concurrency
- Fully functional core logic verified with integration tests

## Building

Requirements: Zig 0.15+

```bash
zig build
```

## Usage

### Basic Usage

```bash
chlogr --repo [org]/[repo]
```

### With Token

```bash
chlogr --repo [org]/[repo] --token ghp_xxxxxxxxxxxx
```

### With Parallel Fetching

```bash
chlogr --repo [org]/[repo] --parallel 4
```

Use `--parallel <N>` on large repositories with many releases, pull requests, and closed issues to fetch all three streams together while letting release and PR pagination use up to `N` concurrent page requests per stream.

### With Closed Issues

```bash
chlogr --repo [org]/[repo] --closed-issues
```

Use `--closed-issues` to include closed issues in the changelog. Issues are filtered from the `/issues` endpoint and grouped by the release they were closed in.

### Options

- `--repo` (required): GitHub repository in the format `[Organization or Username]/[Repository name]`
- `--token` (optional): GitHub API token (falls back to env vars or `gh` CLI)
- `--output` (optional): Output file path (default: CHANGELOG.md)
- `--since-tag` (optional): Start from this tag/version
- `--until-tag` (optional): End at this tag/version
- `--exclude-labels` (optional): Comma-separated labels to exclude (e.g., duplicate,wontfix)
- `--parallel <N>` (optional, default: 4): Fetch releases, pull requests, and closed issues concurrently; release and PR pagination use up to `N` page requests per stream

### Authentication

The tool will attempt to retrieve a GitHub token in this order:

1. `--token` flag
2. `GITHUB_TOKEN` environment variable
3. `GH_TOKEN` environment variable
4. `gh auth token` command (GitHub CLI)

If none are available, the tool will display a helpful error message.

## Example Output

```markdown
# Changelog

## [Unreleased Changes]

### Features

- New unreleased feature Y (#126) (@dave)

### Bug Fixes

- Unreleased bug fix (#127) (@eve)

### Merged Pull Requests

- Work in progress change (#999) (@developer)

## [v1.2.0](https://github.com/owner/repo/releases/tag/v1.2.0) (2024-01-15)

### Merged Pull Requests

- Update documentation (#125) (@charlie)

### Features

- Add new feature X (#123) (@alice)

### Bug Fixes

- Fix critical bug (#124) (@bob)

### Closed Issues

- Close onboarding issue (#910) (@frank)

## [v1.1.0](https://github.com/owner/repo/releases/tag/v1.1.0) (2024-01-10)

### Closed Issues

- Close docs issue (#911) (@grace)
```

## Development

### Running Tests

```bash
zig build test
```

This runs integration tests with mock GitHub data to verify:

- CLI argument parsing (--parallel and all existing flags)
- JSON parsing of releases, PRs, and closed issues
- Changelog grouping and categorization for pull requests and closed issues
- Markdown formatting
- File output

### Project Structure

```
src/
  ├── main.zig                 # Main orchestration logic
  ├── cli.zig                 # CLI argument parsing
  ├── token_resolver.zig      # GitHub token resolution
  ├── models.zig              # Data structures
  ├── http_client.zig         # HTTP client wrapper
  ├── github_api.zig          # GitHub API integration
  ├── changelog_generator.zig # Core changelog logic
  ├── markdown_formatter.zig  # Markdown output formatting
  ├── test_data.zig           # Mock test data
  └── test.zig                # Integration tests
```

## License

MIT
