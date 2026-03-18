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
