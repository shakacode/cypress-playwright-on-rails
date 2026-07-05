# Update Changelog

You are helping update `CHANGELOG.md` for `shakacode/cypress-playwright-on-rails`.

## Arguments

This command accepts an optional argument: `$ARGUMENTS`

- No argument: add missing user-visible entries to `## [Unreleased]`.
- `release`: add entries, then stamp the next stable version with `bundle exec rake update_changelog[release]`.
- `rc`: add entries, then stamp the next release candidate with `bundle exec rake update_changelog[rc]`.
- `beta`: add entries, then stamp the next beta with `bundle exec rake update_changelog[beta]`.
- Explicit version such as `1.21.0.rc.0`: add entries, then stamp that exact version with `bundle exec rake update_changelog[1.21.0.rc.0]`.

After the changelog PR merges, the release task reads the newest stamped changelog version automatically:

```bash
bundle exec rake release
```

## Core Rules

- Add entries only for user-visible changes: features, bug fixes, breaking changes, deprecations, performance improvements, security fixes, and public API/configuration changes.
- Skip linting, formatting, internal refactors, test-only changes, CI changes, and docs-only changes unless the docs correct public behavior.
- Do not ask the user for PR details. Use git history and GitHub.
- Use the repo's current changelog shape:
  - Version headers: `## [1.21.0.rc.0] - YYYY-MM-DD`
  - Category headings: `### Added`, `### Changed`, `### Improved`, `### Fixed`, etc.
  - PR links: `[PR 219](https://github.com/shakacode/cypress-playwright-on-rails/pull/219) by [username](https://github.com/username)`.

## Release Flow

1. Fetch current branch, base branch, and tags:

   ```bash
   git fetch origin master --tags
   ```

2. Inspect merged PRs since the latest release tag:

   ```bash
   git tag -l 'v*' --sort=-v:refname | head -10
   git log --oneline LATEST_TAG..origin/master
   ```

3. Add missing user-visible entries under `## [Unreleased]`, merging into existing category headings.

4. If `$ARGUMENTS` asks for a release stamp, run the rake task:

   ```bash
   bundle exec rake update_changelog[release]
   bundle exec rake update_changelog[rc]
   bundle exec rake update_changelog[beta]
   bundle exec rake update_changelog[1.21.0.rc.0]
   ```

5. Verify:

   ```bash
   bundle exec rake
   ```

6. Commit the changelog update on a branch and open a PR. Once merged, release with:

   ```bash
   git switch master
   git pull --ff-only
   bundle exec rake release
   ```

The release task bumps `lib/cypress_on_rails/version.rb`, updates `Gemfile.lock`, commits, tags, pushes, publishes the gem, and creates or updates the GitHub release from the stamped changelog section.
