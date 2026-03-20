# Changelog

## [Unreleased Changes]

### Merged Pull Requests
- docs: update README with --parallel flag and progress output ([#37](https://github.com/christianhelle/chlogr/pull/37)) ([@christianhelle](https://github.com/christianhelle/))
- docs: add README hygiene rule to copilot instructions ([#38](https://github.com/christianhelle/chlogr/pull/38)) ([@christianhelle](https://github.com/christianhelle/))

### Features
- feat: optimize parallel pagination with link-aware discovery ([#42](https://github.com/christianhelle/chlogr/pull/42)) ([@christianhelle](https://github.com/christianhelle/))
- fix: support arbitrary degree of parallelism in parallel PR fetcher ([#41](https://github.com/christianhelle/chlogr/pull/41)) ([@christianhelle](https://github.com/christianhelle/))
- feat: show per-fetcher progress in parallel mode ([#36](https://github.com/christianhelle/chlogr/pull/36)) ([@christianhelle](https://github.com/christianhelle/))
- feat: wire --parallel flag into main.zig fetch path ([#35](https://github.com/christianhelle/chlogr/pull/35)) ([@christianhelle](https://github.com/christianhelle/))
- feat: implement ParallelFetcher with std.Thread ([#34](https://github.com/christianhelle/chlogr/pull/34)) ([@christianhelle](https://github.com/christianhelle/))
- feat: add progress messages during sequential fetch ([#33](https://github.com/christianhelle/chlogr/pull/33)) ([@christianhelle](https://github.com/christianhelle/))
- feat: add --parallel flag to CLI argument parsing ([#32](https://github.com/christianhelle/chlogr/pull/32)) ([@christianhelle](https://github.com/christianhelle/))
- feat: add link to non-bot pr authors in output changelog ([#39](https://github.com/christianhelle/chlogr/pull/39)) ([@christianhelle](https://github.com/christianhelle/))


## [0.2.5](https://github.com/christianhelle/chlogr/releases/tag/0.2.5) (2026-03-18)

### Features
- fix: add errdefer cleanup to GitHub API deep-copy allocation paths (#6) ([#20](https://github.com/christianhelle/chlogr/pull/20)) ([@christianhelle](https://github.com/christianhelle/))
- feat: sort the changelog by newest-first ([#25](https://github.com/christianhelle/chlogr/pull/25)) ([@christianhelle](https://github.com/christianhelle/))
- fix: hardcoded version in help text ([#26](https://github.com/christianhelle/chlogr/pull/26)) ([@christianhelle](https://github.com/christianhelle/))
- perf: reduce allocation churn in generator and formatter ([#24](https://github.com/christianhelle/chlogr/pull/24)) ([@christianhelle](https://github.com/christianhelle/))
- fix: use --repo slug in generated markdown links ([#23](https://github.com/christianhelle/chlogr/pull/23)) ([@christianhelle](https://github.com/christianhelle/))
- fix: exact CSV token matching for --exclude-labels ([#22](https://github.com/christianhelle/chlogr/pull/22)) ([@christianhelle](https://github.com/christianhelle/))
- feat: implement pagination for releases and merged pull requests (#7) ([#21](https://github.com/christianhelle/chlogr/pull/21)) ([@christianhelle](https://github.com/christianhelle/))
- fix: assign each PR to exactly one release using full timestamp comparison (#5) ([#19](https://github.com/christianhelle/chlogr/pull/19)) ([@christianhelle](https://github.com/christianhelle/))
- feat: implement --since-tag and --until-tag filtering (#8) ([#18](https://github.com/christianhelle/chlogr/pull/18)) ([@christianhelle](https://github.com/christianhelle/))
- fix: safe section-map initialization and propagate allocation failures (#3) ([#17](https://github.com/christianhelle/chlogr/pull/17)) ([@christianhelle](https://github.com/christianhelle/))
- fix: harden gh token resolution against panics and stderr deadlock (#4) ([#16](https://github.com/christianhelle/chlogr/pull/16)) ([@christianhelle](https://github.com/christianhelle/))
- chore: add copilot instructions for agent workflow ([#15](https://github.com/christianhelle/chlogr/pull/15)) ([@christianhelle](https://github.com/christianhelle/))


## [0.1.4](https://github.com/christianhelle/chlogr/releases/tag/0.1.4) (2026-03-18)

### Features
- Remove time from release dates in output ([#12](https://github.com/christianhelle/chlogr/pull/12)) ([@christianhelle](https://github.com/christianhelle/))


## [0.1.3](https://github.com/christianhelle/chlogr/releases/tag/0.1.3) (2026-03-17)

### Features
- feat: merge --owner argument into --repo ([#2](https://github.com/christianhelle/chlogr/pull/2)) ([@christianhelle](https://github.com/christianhelle/))


## [0.1.2](https://github.com/christianhelle/chlogr/releases/tag/0.1.2) (2026-03-16)

### Features
- feat: zero-dependency http client ([#1](https://github.com/christianhelle/chlogr/pull/1)) ([@christianhelle](https://github.com/christianhelle/))


