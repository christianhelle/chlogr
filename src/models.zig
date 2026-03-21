const std = @import("std");

pub const Release = struct {
    tag_name: []const u8,
    name: []const u8,
    published_at: []const u8,
};

pub const PullRequest = struct {
    number: u32,
    title: []const u8,
    body: ?[]const u8,
    html_url: []const u8,
    user: User,
    labels: []Label,
    merged_at: ?[]const u8,
};

pub const IssuePullRequestRef = struct {
    url: ?[]const u8 = null,
};

pub const Issue = struct {
    number: u32,
    title: []const u8,
    body: ?[]const u8,
    html_url: []const u8,
    user: User,
    labels: []Label,
    closed_at: ?[]const u8 = null,
    pull_request: ?IssuePullRequestRef = null,
};

pub const Label = struct {
    name: []const u8,
    color: []const u8,
};

pub const User = struct {
    login: []const u8,
    html_url: []const u8,
};

pub const Repository = struct {
    name: []const u8,
    full_name: []const u8,
    description: ?[]const u8,
    html_url: []const u8,
};
