# Changelog Generator

A fast, efficient, native CLI tool to automatically generate changelogs from GitHub tags, pull requests, and issues. Written in Zig

## Features

- Fast, compiled binary (zero dependencies, pure Zig stdlib)
- Generates Markdown changelogs automatically
- Categorizes entries by labels (Features, Bug Fixes, Other)
- Links to PRs, issues, and contributors
- Smart token resolution (--token flag → env vars → `gh auth token` CLI)
- Works with any GitHub repository
- Fully functional core logic verified with integration tests

## Building

Requirements: Zig 0.15+

```bash
zig build
```

## Usage

### Basic Usage

```bash
./zig-out/bin/chlogr \
  --repo github/cli \
  --output CHANGELOG.md
```

### With Token

```bash
./zig-out/bin/chlogr \
  --repo github/cli \
  --token ghp_xxxxxxxxxxxx \
  --output CHANGELOG.md
```

### Options

- `--repo` (required): GitHub repository in the format `[Organization or Username]/[Repository name]`
- `--token` (optional): GitHub API token (falls back to env vars or `gh` CLI)
- `--output` (optional): Output file path (default: CHANGELOG.md)
- `--since-tag` (optional): Start from this tag/version
- `--until-tag` (optional): End at this tag/version
- `--exclude-labels` (optional): Comma-separated labels to exclude (e.g., duplicate,wontfix)

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

## [v1.2.0](https://github.com/owner/repo/releases/tag/v1.2.0) (2024-01-15)

### Features

- Add new feature X (#123) (@alice)

### Bug Fixes

- Fix critical bug (#124) (@bob)

### Other

- Update documentation (#125) (@charlie)

## [v1.1.0](https://github.com/owner/repo/releases/tag/v1.1.0) (2024-01-10)

...
```

## Development

### Running Tests

```bash
zig build test
```

This runs integration tests with mock GitHub data to verify:

- JSON parsing of releases and PRs
- Changelog grouping and categorization
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
