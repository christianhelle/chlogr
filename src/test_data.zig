const std = @import("std");

pub const test_releases =
    \\[
    \\  {
    \\    "tag_name": "v1.2.0",
    \\    "name": "Release v1.2.0",
    \\    "published_at": "2024-01-15T10:30:00Z"
    \\  },
    \\  {
    \\    "tag_name": "v1.1.0",
    \\    "name": "Release v1.1.0",
    \\    "published_at": "2024-01-10T08:15:00Z"
    \\  }
    \\]
;

pub const test_pull_requests =
    \\[
    \\  {
    \\    "number": 123,
    \\    "title": "Add new feature X",
    \\    "body": "This PR adds feature X",
    \\    "html_url": "https://github.com/owner/repo/pull/123",
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
    \\    "merged_at": "2024-01-14T12:00:00Z"
    \\  },
    \\  {
    \\    "number": 124,
    \\    "title": "Fix critical bug",
    \\    "body": "This fixes bug in module X",
    \\    "html_url": "https://github.com/owner/repo/pull/124",
    \\    "user": {
    \\      "login": "bob",
    \\      "html_url": "https://github.com/bob"
    \\    },
    \\    "labels": [
    \\      {
    \\        "name": "bug",
    \\        "color": "d73a4a"
    \\      }
    \\    ],
    \\    "merged_at": "2024-01-12T10:00:00Z"
    \\  },
    \\  {
    \\    "number": 125,
    \\    "title": "Update documentation",
    \\    "body": "Documentation updates",
    \\    "html_url": "https://github.com/owner/repo/pull/125",
    \\    "user": {
    \\      "login": "charlie",
    \\      "html_url": "https://github.com/charlie"
    \\    },
    \\    "labels": [],
    \\    "merged_at": "2024-01-11T14:00:00Z"
    \\  },
    \\  {
    \\    "number": 126,
    \\    "title": "New unreleased feature Y",
    \\    "body": "This is an unreleased feature",
    \\    "html_url": "https://github.com/owner/repo/pull/126",
    \\    "user": {
    \\      "login": "dave",
    \\      "html_url": "https://github.com/dave"
    \\    },
    \\    "labels": [
    \\      {
    \\        "name": "enhancement",
    \\        "color": "84b6eb"
    \\      }
    \\    ],
    \\    "merged_at": "2024-01-16T10:00:00Z"
    \\  },
    \\  {
    \\    "number": 127,
    \\    "title": "Unreleased bug fix",
    \\    "body": "This fixes an unreleased bug",
    \\    "html_url": "https://github.com/owner/repo/pull/127",
    \\    "user": {
    \\      "login": "eve",
    \\      "html_url": "https://github.com/eve"
    \\    },
    \\    "labels": [
    \\      {
    \\        "name": "bugfix",
    \\        "color": "d73a4a"
    \\      }
    \\    ],
    \\    "merged_at": "2024-01-17T11:00:00Z"
    \\  }
    \\]
;

pub const test_releases_with_unreleased =
    \\[
    \\  {
    \\    "tag_name": "v1.0.0",
    \\    "name": "Release v1.0.0",
    \\    "published_at": "2024-01-01T00:00:00Z"
    \\  }
    \\]
;

pub const test_pull_requests_all_merged_before_release =
    \\[
    \\  {
    \\    "number": 100,
    \\    "title": "Initial feature",
    \\    "body": "Initial feature",
    \\    "html_url": "https://github.com/owner/repo/pull/100",
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
    \\    "merged_at": "2023-12-31T23:00:00Z"
    \\  }
    \\]
;

pub const test_pull_requests_all_unreleased =
    \\[
    \\  {
    \\    "number": 200,
    \\    "title": "WIP feature",
    \\    "body": "Work in progress",
    \\    "html_url": "https://github.com/owner/repo/pull/200",
    \\    "user": {
    \\      "login": "bob",
    \\      "html_url": "https://github.com/bob"
    \\    },
    \\    "labels": [
    \\      {
    \\        "name": "feature",
    \\        "color": "0366d6"
    \\      }
    \\    ],
    \\    "merged_at": "2024-02-01T12:00:00Z"
    \\  },
    \\  {
    \\    "number": 201,
    \\    "title": "Another WIP feature",
    \\    "body": "Another work in progress",
    \\    "html_url": "https://github.com/owner/repo/pull/201",
    \\    "user": {
    \\      "login": "charlie",
    \\      "html_url": "https://github.com/charlie"
    \\    },
    \\    "labels": [],
    \\    "merged_at": "2024-02-02T14:00:00Z"
    \\  }
    \\]
;

pub const test_closed_issues =
    \\[
    \\  {
    \\    "number": 910,
    \\    "title": "Close onboarding issue",
    \\    "body": "Closed before v1.2.0",
    \\    "html_url": "https://github.com/owner/repo/issues/910",
    \\    "user": {
    \\      "login": "frank",
    \\      "html_url": "https://github.com/frank"
    \\    },
    \\    "labels": [
    \\      {
    \\        "name": "bug",
    \\        "color": "d73a4a"
    \\      }
    \\    ],
    \\    "closed_at": "2024-01-14T09:00:00Z"
    \\  },
    \\  {
    \\    "number": 911,
    \\    "title": "Close docs issue",
    \\    "body": "Closed before v1.1.0",
    \\    "html_url": "https://github.com/owner/repo/issues/911",
    \\    "user": {
    \\      "login": "grace",
    \\      "html_url": "https://github.com/grace"
    \\    },
    \\    "labels": [
    \\      {
    \\        "name": "enhancement",
    \\        "color": "84b6eb"
    \\      }
    \\    ],
    \\    "closed_at": "2024-01-09T12:00:00Z"
    \\  },
    \\  {
    \\    "number": 912,
    \\    "title": "Close unreleased issue",
    \\    "body": "Closed after the latest release",
    \\    "html_url": "https://github.com/owner/repo/issues/912",
    \\    "user": {
    \\      "login": "heidi",
    \\      "html_url": "https://github.com/heidi"
    \\    },
    \\    "labels": [],
    \\    "closed_at": "2024-01-16T10:00:00Z"
    \\  }
    \\]
;

pub const test_closed_issues_with_excluded_labels =
    \\[
    \\  {
    \\    "number": 920,
    \\    "title": "Visible closed issue",
    \\    "body": "Should remain in the changelog",
    \\    "html_url": "https://github.com/owner/repo/issues/920",
    \\    "user": {
    \\      "login": "ivan",
    \\      "html_url": "https://github.com/ivan"
    \\    },
    \\    "labels": [],
    \\    "closed_at": "2024-01-14T10:00:00Z"
    \\  },
    \\  {
    \\    "number": 921,
    \\    "title": "Hidden closed issue",
    \\    "body": "Should be filtered out by exclude-labels",
    \\    "html_url": "https://github.com/owner/repo/issues/921",
    \\    "user": {
    \\      "login": "judy",
    \\      "html_url": "https://github.com/judy"
    \\    },
    \\    "labels": [
    \\      {
    \\        "name": "wontfix",
    \\        "color": "cccccc"
    \\      }
    \\    ],
    \\    "closed_at": "2024-01-14T11:00:00Z"
    \\  }
    \\]
;

pub const test_closed_issues_with_pull_request_marker =
    \\[
    \\  {
    \\    "number": 910,
    \\    "title": "Close onboarding issue",
    \\    "body": "Closed before v1.2.0",
    \\    "html_url": "https://github.com/owner/repo/issues/910",
    \\    "user": {
    \\      "login": "frank",
    \\      "html_url": "https://github.com/frank"
    \\    },
    \\    "labels": [],
    \\    "closed_at": "2024-01-13T09:00:00Z"
    \\  },
    \\  {
    \\    "number": 911,
    \\    "title": "Pull request returned by issues API",
    \\    "body": "Must be filtered out",
    \\    "html_url": "https://github.com/owner/repo/pull/911",
    \\    "user": {
    \\      "login": "lee",
    \\      "html_url": "https://github.com/lee"
    \\    },
    \\    "labels": [],
    \\    "closed_at": "2024-01-14T10:00:00Z",
    \\    "pull_request": {
    \\      "url": "https://api.github.com/repos/owner/repo/pulls/911"
    \\    }
    \\  },
    \\  {
    \\    "number": 912,
    \\    "title": "Close docs issue",
    \\    "body": "Another real issue payload",
    \\    "html_url": "https://github.com/owner/repo/issues/912",
    \\    "user": {
    \\      "login": "grace",
    \\      "html_url": "https://github.com/grace"
    \\    },
    \\    "labels": [],
    \\    "closed_at": "2024-01-14T11:00:00Z"
    \\  }
    \\]
;

pub const test_pull_requests_with_excluded_labels =
    \\[
    \\  {
    \\    "number": 300,
    \\    "title": "Should be included",
    \\    "body": "Regular PR",
    \\    "html_url": "https://github.com/owner/repo/pull/300",
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
    \\    "merged_at": "2024-01-14T12:00:00Z"
    \\  },
    \\  {
    \\    "number": 301,
    \\    "title": "Should be excluded",
    \\    "body": "PR with excluded label",
    \\    "html_url": "https://github.com/owner/repo/pull/301",
    \\    "user": {
    \\      "login": "bob",
    \\      "html_url": "https://github.com/bob"
    \\    },
    \\    "labels": [
    \\      {
    \\        "name": "wontfix",
    \\        "color": "cccccc"
    \\      }
    \\    ],
    \\    "merged_at": "2024-01-14T13:00:00Z"
    \\  },
    \\  {
    \\    "number": 302,
    \\    "title": "Should also be excluded",
    \\    "body": "PR with another excluded label",
    \\    "html_url": "https://github.com/owner/repo/pull/302",
    \\    "user": {
    \\      "login": "charlie",
    \\      "html_url": "https://github.com/charlie"
    \\    },
    \\    "labels": [
    \\      {
    \\        "name": "wontfix",
    \\        "color": "cccccc"
    \\      }
    \\    ],
    \\    "merged_at": "2024-01-16T10:00:00Z"
    \\  }
    \\]
;

pub const test_pull_requests_no_merged_at =
    \\[
    \\  {
    \\    "number": 400,
    \\    "title": "PR without merge date",
    \\    "body": "This PR has no merged_at",
    \\    "html_url": "https://github.com/owner/repo/pull/400",
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
    \\    "merged_at": null
    \\  }
    \\]
;

pub const test_empty_releases =
    \\[]
;

pub const test_empty_prs =
    \\[]
;

// Regression: same-day / same-timestamp boundary — PR merged at exact release timestamp
// must appear in that release, not in unreleased.
pub const test_releases_same_day =
    \\[
    \\  {
    \\    "tag_name": "v2.0.0",
    \\    "name": "Release v2.0.0",
    \\    "published_at": "2024-03-01T12:00:00Z"
    \\  }
    \\]
;

pub const test_pull_requests_same_day_as_release =
    \\[
    \\  {
    \\    "number": 500,
    \\    "title": "Same-timestamp merge PR",
    \\    "body": "Merged at the exact same timestamp as the release",
    \\    "html_url": "https://github.com/owner/repo/pull/500",
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
    \\    "merged_at": "2024-03-01T12:00:00Z"
    \\  }
    \\]
;

// Regression: duplicate prevention — a PR merged before both releases must appear in
// exactly one section (the oldest qualifying release), not in both.
pub const test_releases_two_versions =
    \\[
    \\  {
    \\    "tag_name": "v1.0.0",
    \\    "name": "Release v1.0.0",
    \\    "published_at": "2024-01-01T10:00:00Z"
    \\  },
    \\  {
    \\    "tag_name": "v2.0.0",
    \\    "name": "Release v2.0.0",
    \\    "published_at": "2024-02-01T10:00:00Z"
    \\  }
    \\]
;

pub const test_pull_requests_pre_first_release =
    \\[
    \\  {
    \\    "number": 600,
    \\    "title": "Pre-release PR",
    \\    "body": "Merged before the first release",
    \\    "html_url": "https://github.com/owner/repo/pull/600",
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
    \\    "merged_at": "2023-12-01T10:00:00Z"
    \\  }
    \\]
;

pub const test_releases_four_versions =
    \\[
    \\  {
    \\    "tag_name": "v1.3.0",
    \\    "name": "Release v1.3.0",
    \\    "published_at": "2024-03-01T10:00:00Z"
    \\  },
    \\  {
    \\    "tag_name": "v1.2.0",
    \\    "name": "Release v1.2.0",
    \\    "published_at": "2024-02-01T10:00:00Z"
    \\  },
    \\  {
    \\    "tag_name": "v1.1.0",
    \\    "name": "Release v1.1.0",
    \\    "published_at": "2024-01-15T10:00:00Z"
    \\  },
    \\  {
    \\    "tag_name": "v1.0.0",
    \\    "name": "Release v1.0.0",
    \\    "published_at": "2024-01-01T10:00:00Z"
    \\  }
    \\]
;

// Exact-match exclusion test data.
// PR #700 has label "bug" → must be excluded when exclude_labels = "bug".
// PR #701 has label "bug-fix" → must NOT be excluded (substring, not exact match).
// PR #702 has label "debug" → must NOT be excluded (substring, not exact match).
// All merged before v1.1.0 (2024-01-10) so they land in a release.
pub const test_prs_exact_label_match =
    \\[
    \\  {
    \\    "number": 700,
    \\    "title": "Has exact bug label",
    \\    "body": null,
    \\    "html_url": "https://github.com/owner/repo/pull/700",
    \\    "user": { "login": "alice", "html_url": "https://github.com/alice" },
    \\    "labels": [{ "name": "bug", "color": "d73a4a" }],
    \\    "merged_at": "2024-01-09T10:00:00Z"
    \\  },
    \\  {
    \\    "number": 701,
    \\    "title": "Has bug-fix label",
    \\    "body": null,
    \\    "html_url": "https://github.com/owner/repo/pull/701",
    \\    "user": { "login": "bob", "html_url": "https://github.com/bob" },
    \\    "labels": [{ "name": "bug-fix", "color": "d73a4a" }],
    \\    "merged_at": "2024-01-09T11:00:00Z"
    \\  },
    \\  {
    \\    "number": 702,
    \\    "title": "Has debug label",
    \\    "body": null,
    \\    "html_url": "https://github.com/owner/repo/pull/702",
    \\    "user": { "login": "charlie", "html_url": "https://github.com/charlie" },
    \\    "labels": [{ "name": "debug", "color": "e4e669" }],
    \\    "merged_at": "2024-01-09T12:00:00Z"
    \\  }
    \\]
;

// CSV exclusion test data.
// PR #800 has label "bug" and PR #801 has label "enhancement" → both excluded by "bug,enhancement".
// PR #802 has label "feature" → must NOT be excluded.
// All merged before v1.1.0 (2024-01-10) so they land in a release.
pub const test_prs_csv_labels =
    \\[
    \\  {
    \\    "number": 800,
    \\    "title": "CSV bug PR",
    \\    "body": null,
    \\    "html_url": "https://github.com/owner/repo/pull/800",
    \\    "user": { "login": "alice", "html_url": "https://github.com/alice" },
    \\    "labels": [{ "name": "bug", "color": "d73a4a" }],
    \\    "merged_at": "2024-01-09T10:00:00Z"
    \\  },
    \\  {
    \\    "number": 801,
    \\    "title": "CSV enhancement PR",
    \\    "body": null,
    \\    "html_url": "https://github.com/owner/repo/pull/801",
    \\    "user": { "login": "bob", "html_url": "https://github.com/bob" },
    \\    "labels": [{ "name": "enhancement", "color": "84b6eb" }],
    \\    "merged_at": "2024-01-09T11:00:00Z"
    \\  },
    \\  {
    \\    "number": 802,
    \\    "title": "CSV feature PR",
    \\    "body": null,
    \\    "html_url": "https://github.com/owner/repo/pull/802",
    \\    "user": { "login": "charlie", "html_url": "https://github.com/charlie" },
    \\    "labels": [{ "name": "feature", "color": "0366d6" }],
    \\    "merged_at": "2024-01-09T12:00:00Z"
    \\  }
    \\]
;

pub const test_prs_for_four_versions =
    \\[
    \\  {
    \\    "number": 500,
    \\    "title": "v1.3.0 feature",
    \\    "body": null,
    \\    "html_url": "https://github.com/owner/repo/pull/500",
    \\    "user": { "login": "alice", "html_url": "https://github.com/alice" },
    \\    "labels": [{ "name": "feature", "color": "0366d6" }],
    \\    "merged_at": "2024-02-28T12:00:00Z"
    \\  },
    \\  {
    \\    "number": 501,
    \\    "title": "v1.2.0 fix",
    \\    "body": null,
    \\    "html_url": "https://github.com/owner/repo/pull/501",
    \\    "user": { "login": "bob", "html_url": "https://github.com/bob" },
    \\    "labels": [{ "name": "bug", "color": "d73a4a" }],
    \\    "merged_at": "2024-01-31T12:00:00Z"
    \\  },
    \\  {
    \\    "number": 502,
    \\    "title": "v1.1.0 enhancement",
    \\    "body": null,
    \\    "html_url": "https://github.com/owner/repo/pull/502",
    \\    "user": { "login": "charlie", "html_url": "https://github.com/charlie" },
    \\    "labels": [{ "name": "enhancement", "color": "84b6eb" }],
    \\    "merged_at": "2024-01-14T12:00:00Z"
    \\  },
    \\  {
    \\    "number": 503,
    \\    "title": "v1.0.0 initial",
    \\    "body": null,
    \\    "html_url": "https://github.com/owner/repo/pull/503",
    \\    "user": { "login": "dave", "html_url": "https://github.com/dave" },
    \\    "labels": [],
    \\    "merged_at": "2023-12-31T12:00:00Z"
    \\  }
    \\]
;

pub const test_prs_link_header_last_page =
    \\<https://api.github.com/repos/owner/repo/pulls?state=closed&page=2&per_page=100&sort=updated&direction=desc>; rel="next", <https://api.github.com/repos/owner/repo/pulls?state=closed&page=4&per_page=100&sort=updated&direction=desc>; rel="last"
;

pub const test_prs_link_header_next_only =
    \\<https://api.github.com/repos/owner/repo/pulls?state=closed&page=2&per_page=100&sort=updated&direction=desc>; rel="next"
;

pub const test_prs_link_header_malformed_last =
    \\<https://api.github.com/repos/owner/repo/pulls?state=closed&page=2&per_page=100&sort=updated&direction=desc>; rel="next", <https://api.github.com/repos/owner/repo/pulls?state=closed&page=oops&per_page=100&sort=updated&direction=desc>; rel="last"
;

pub const test_releases_link_header_multiple_relations =
    \\<https://api.github.com/repos/owner/repo/releases?page=1&per_page=100>; rel="prev", <https://api.github.com/repos/owner/repo/releases?page=2&per_page=100>; rel="next", <https://api.github.com/repos/owner/repo/releases?page=3&per_page=100>; rel="last"
;
