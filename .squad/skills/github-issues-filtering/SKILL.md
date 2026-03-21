# GitHub Issues Filtering

## When to use

Use this pattern when a feature consumes GitHub's `/issues` endpoint for changelogs, release notes, dashboards, or any report that should include true issues but not pull requests.

## Pattern

1. Extend the issue model with `closed_at` and an optional `pull_request` marker.
2. Filter `pull_request` entries as close to the API boundary as possible when copying parsed issue payloads.
3. Keep a second defensive skip in the domain layer so malformed or hand-built fixtures cannot accidentally reintroduce PR-as-issue duplication.
4. Group true issues into a dedicated `Closed Issues` section by `closed_at`, using the same release-boundary rule as merged pull requests.
5. Reuse existing exclude-label logic if the repository already supports label-based suppression.
6. If the product contract says unreleased output is PR-only, omit unassigned issues instead of inventing an unreleased `Closed Issues` section.

## Useful files in chlogr

- `src/models.zig`
- `src/github_api.zig`
- `src/changelog_generator.zig`
- `src/test_data.zig`
- `src/test.zig`

## Validation

- Verify issues land in the correct release bucket.
- Verify markdown renders a `Closed Issues` section.
- Verify pull requests from `/issues` are filtered out.
- Run `zig build && zig build test`.
