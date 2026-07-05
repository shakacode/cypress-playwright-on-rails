# Release Process

This project follows the ShakaCode release shape used by Shakapacker and React on Rails:
update and stamp the changelog first, merge that PR, then run the release task with no version argument.

## Prerequisites

1. Maintainer access to `shakacode/cypress-playwright-on-rails`.
2. RubyGems publish access for `cypress-on-rails`.
3. Authenticated GitHub CLI with write access: `gh auth status`.
4. Clean checkout on `master`.
5. Dependencies installed: `bundle install`.

## Recommended Flow

1. Update and stamp the changelog in a PR:

   ```bash
   # For a stable release
   /update-changelog release

   # For a release candidate
   /update-changelog rc

   # Or explicitly
   /update-changelog 1.21.0.rc.0
   ```

   The command should add user-visible entries to `## [Unreleased]`, then run the matching rake task:

   ```bash
   bundle exec rake update_changelog[release]
   bundle exec rake update_changelog[rc]
   bundle exec rake update_changelog[1.21.0.rc.0]
   ```

2. Merge the changelog PR.

3. Release from an up-to-date `master`:

   ```bash
   git switch master
   git pull --ff-only
   bundle exec rake release
   ```

   With no version argument, `rake release` reads the newest version header in `CHANGELOG.md`.

## Useful Commands

```bash
# Dry run using the changelog-stamped version
bundle exec rake "release[,true]"

# Explicit version
bundle exec rake "release[1.21.0.rc.0]"

# Override version-policy checks, only when intentional
bundle exec rake "release[1.21.0,false,true]"

# Re-sync GitHub release notes from CHANGELOG.md
bundle exec rake "sync_github_release[1.21.0]"
```

## What `rake release` Does

1. Verifies the worktree is clean.
2. Verifies GitHub CLI auth and repository write access.
3. Resolves the release version from `CHANGELOG.md`, or falls back to a patch bump.
4. Validates the requested version is newer than existing tags and matches the changelog bump shape for stable releases.
5. Bumps `lib/cypress_on_rails/version.rb`.
6. Runs `bundle install` to update `Gemfile.lock`.
7. Commits the release metadata.
8. Creates and pushes `vVERSION`.
9. Publishes the gem to RubyGems.
10. Creates or updates the GitHub release from that version's `CHANGELOG.md` section.

Dry runs use a temporary git worktree so the main checkout is not dirtied.

## Version Numbering

- Major: breaking changes.
- Minor: backward-compatible features.
- Patch: backward-compatible fixes.
- Prerelease: use RubyGems dot notation, such as `1.21.0.rc.0` or `1.21.0.beta.0`.

## Troubleshooting

### Missing changelog section

Run `/update-changelog release`, `/update-changelog rc`, or:

```bash
bundle exec rake update_changelog[1.21.0.rc.0]
```

### RubyGems publish failure

Fix authentication or OTP issues, then retry from the same checkout:

```bash
gem release
bundle exec rake "sync_github_release[VERSION]"
```

### Version policy failure

Confirm the latest git tags and changelog headings. If the release is intentionally unusual:

```bash
RELEASE_VERSION_POLICY_OVERRIDE=true bundle exec rake release
```
