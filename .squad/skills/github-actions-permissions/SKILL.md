---
name: "github-actions-permissions"
description: "Correct GitHub Actions permission scoping for PR and issue operations"
domain: "ci-cd, github-actions"
confidence: "high"
source: "earned — discovered via workflow debugging"
---

## Context

GitHub Actions workflows require explicit permissions when using `GITHUB_TOKEN` to interact with the GitHub API. The permission model is namespace-based and follows GitHub's API structure, which has a critical quirk: **pull requests use the `issues` API namespace for labels, assignees, and milestones**.

This skill applies when:
- Writing workflows that automate PR metadata (labels, assignees, milestones)
- Debugging permission errors in workflows that manipulate PRs
- Designing cross-repo workflow templates

## Patterns

### Permission Scopes for PR Operations

**Common misconception:** PR operations need `pull-requests: write`

**Reality:** Most PR metadata operations need `issues: write`

```yaml
# ✅ CORRECT — For adding labels, assignees, or milestones to PRs
permissions:
  issues: write
  contents: read
```

```yaml
# ❌ INCORRECT — Will fail when calling issues.* APIs
permissions:
  pull-requests: write
  contents: read
```

### API Namespace Mapping

| Operation | API Namespace | Required Permission |
|-----------|---------------|---------------------|
| Add label to PR | `issues.addLabels()` | `issues: write` |
| Assign PR | `issues.addAssignees()` | `issues: write` |
| Add milestone to PR | `issues.addMilestone()` | `issues: write` |
| Comment on PR | `issues.createComment()` | `issues: write` |
| Request review | `pulls.requestReviewers()` | `pull-requests: write` |
| Merge PR | `pulls.merge()` | `pull-requests: write` |
| Convert to draft | `pulls.update()` | `pull-requests: write` |

### Label Lifecycle Pattern

When building label automation, follow this dependency chain:

1. **Label sync workflow** (authoritative source)
   - Defines all canonical labels
   - Runs on team roster changes or manual trigger
   - Uses `issues: write` permission

2. **PR metadata workflow** (consumer)
   - Applies labels to PRs based on rules
   - Depends on labels existing (created by sync workflow)
   - Uses `issues: write` permission

**Anti-pattern:** Having PR workflow create labels on-the-fly → leads to inconsistent colors/descriptions

**Correct pattern:** Label sync creates/updates, PR workflow applies

## Examples

### Example 1: PR Auto-Labeling Workflow

```yaml
name: PR Squad Metadata

on:
  pull_request:
    types: [opened, reopened]

permissions:
  issues: write  # Required for labels and assignees
  contents: read # Required for checkout

jobs:
  label-and-assign:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Add label and assign
        uses: actions/github-script@v7
        with:
          script: |
            const pr = context.payload.pull_request;
            
            // Add label (uses issues API)
            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: pr.number,  # Note: "issue_number" for PRs
              labels: ['enhancement']
            });
            
            // Assign (uses issues API)
            await github.rest.issues.addAssignees({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: pr.number,
              assignees: ['maintainer']
            });
```

### Example 2: Label Sync Workflow

```yaml
name: Sync Squad Labels

on:
  workflow_dispatch:
  push:
    paths: ['.squad/team.md']

permissions:
  issues: write   # Required for label creation/updates
  contents: read  # Required for checkout

jobs:
  sync-labels:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Create or update labels
        uses: actions/github-script@v7
        with:
          script: |
            const labels = [
              { name: 'enhancement', color: 'A2EEEF', description: 'New feature or improvement' },
              { name: 'bug', color: 'FF0422', description: 'Something isn\'t working' }
            ];
            
            for (const label of labels) {
              try {
                await github.rest.issues.getLabel({
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  name: label.name
                });
                // Exists — update
                await github.rest.issues.updateLabel({
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  name: label.name,
                  color: label.color,
                  description: label.description
                });
              } catch (err) {
                if (err.status === 404) {
                  // Doesn't exist — create
                  await github.rest.issues.createLabel({
                    owner: context.repo.owner,
                    repo: context.repo.repo,
                    name: label.name,
                    color: label.color,
                    description: label.description
                  });
                }
              }
            }
```

## Anti-Patterns

### ❌ Using pull-requests: write for label operations

```yaml
# This will FAIL when calling issues.addLabels()
permissions:
  pull-requests: write
  contents: read
```

**Error message you'll see:**
```
Resource not accessible by integration
```

### ❌ Creating labels on-the-fly in PR workflows

```yaml
# Bad: Every PR creates its own label (inconsistent colors, no source of truth)
await github.rest.issues.createLabel({
  name: 'enhancement',
  color: 'RANDOM_COLOR'  # Different each time!
});
```

**Correct approach:** Separate label sync workflow as authoritative source

### ❌ Hardcoding issue_number instead of using PR number

```yaml
# Bad: Using a literal number
issue_number: 42

# Good: Using the PR number from context
issue_number: context.payload.pull_request.number
```

## Quick Reference

**Debugging permission errors:**

1. Check workflow logs for "Resource not accessible by integration"
2. Identify which API namespace the script uses (`issues.*` vs `pulls.*`)
3. Update `permissions:` block to match the API namespace
4. Re-run workflow

**Rule of thumb:**
- If the script calls `github.rest.issues.*` → need `issues: write`
- If the script calls `github.rest.pulls.*` → need `pull-requests: write`
- Most PR automation needs `issues: write`

## Related Patterns

- **Label lifecycle management** — Use sync workflow + consumer pattern
- **Graceful degradation** — Wrap API calls in try/catch, use `core.warning()` instead of failing
- **Template synchronization** — Keep `.github/workflows/` and `.squad/templates/workflows/` in sync
