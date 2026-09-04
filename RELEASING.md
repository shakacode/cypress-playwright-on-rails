# Release Process

This project follows the ShakaCode release shape used by Shakapacker and React on Rails:
update and stamp the changelog first, merge that PR, then run the release task with no version argument.

## The Two Gems

Each release publishes two gems at the same version:

| Gem | Source | Purpose |
| --- | --- | --- |
| `cypress-on-rails` | repository root | the real gem |
| `e2e_on_rails` | `alias_gem/` | thin alias that reserves the canonical name adopted at 2.0 (see `docs/adr/0001-reserve-e2e_on_rails-rename-at-2.0.md`) |

`alias_gem/e2e_on_rails.gemspec` reads `lib/cypress_on_rails/version.rb`, so the
alias always mirrors the parent version and depends on exactly that version
(`cypress-on-rails = VERSION`). An exact pin keeps the two gems locked together
and lets a prerelease alias resolve the matching prerelease parent, which a
`~>` requirement would exclude. There is nothing to bump by hand.

`rake release` publishes `cypress-on-rails` first, then builds and pushes the
alias. The alias is a second `gem push`, so with MFA enabled you are prompted
for a second OTP after the one for the main gem. If the alias build or push
fails, the task warns and continues — the main release is never rolled back.
Retry the alias on its own with:

```bash
(cd alias_gem && gem build e2e_on_rails.gemspec && gem push e2e_on_rails-VERSION.gem)
```

The alias gemspec must be built from `alias_gem/`, because RubyGems resolves
`spec.files` relative to the current directory. Building it from the repository
root raises a descriptive error instead of packaging the wrong files.

## Prerequisites

1. Maintainer access to `shakacode/cypress-playwright-on-rails`.
2. RubyGems publish access for `cypress-on-rails` and `e2e_on_rails`.
3. Authenticated GitHub CLI with write access: `gh auth status`.
4. Clean checkout on `master`.
5. Dependencies installed: `bundle install`.

### One-time: first publish of `e2e_on_rails`

`e2e_on_rails` has never been published. RubyGems will not accept a push from
Nothing blocks the push technically — a first `gem push` creates the gem and
makes the pusher its owner. The first publish is a deliberate manual step for
three reasons:

- ADR-0001 requires re-checking on rubygems.org that the name is still unclaimed
  immediately before the first publish. That check needs a human.
- Whoever pushes first becomes the sole owner, so ownership should be set on
  purpose and co-maintainers added right away, not left to whoever runs the
  next release.
- The alias pins `cypress-on-rails` to the exact same version, so that version
  must already be live on RubyGems when the alias is pushed. Publishing the
  alias first leaves it uninstallable until the parent lands.

Steps:

1. Re-verify the name is still unclaimed: `gem owner e2e_on_rails` should report
   that the gem does not exist. If someone else has claimed it, stop and revisit
   ADR-0001 before releasing.
2. After `cypress-on-rails VERSION` is live on RubyGems, from an up-to-date
   `master` at that same version:

   ```bash
   (cd alias_gem && gem build e2e_on_rails.gemspec)
   gem push alias_gem/e2e_on_rails-VERSION.gem   # asks for your RubyGems OTP
   rm alias_gem/e2e_on_rails-VERSION.gem
   ```

3. Confirm ownership and add the other release maintainers:

   ```bash
   gem owner e2e_on_rails
   gem owner e2e_on_rails --add EMAIL
   ```

After that first push, `rake release` handles the alias automatically on every
subsequent release.

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
   bundle exec rake "update_changelog[release]"
   bundle exec rake "update_changelog[rc]"
   bundle exec rake "update_changelog[1.21.0.rc.0]"
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

# Override version-policy checks, only when intentional.
# The rake argument and RELEASE_VERSION_POLICY_OVERRIDE=true are equivalent.
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
6. Runs `bundle install` to verify dependencies.
7. Commits the release metadata.
8. Creates and pushes `vVERSION`.
9. Publishes `cypress-on-rails` to RubyGems.
10. Builds and pushes the `e2e_on_rails` alias gem at the same version; a failure here warns and continues.
11. Creates or updates the GitHub release from that version's `CHANGELOG.md` section.

Dry runs use a temporary git worktree so the main checkout is not dirtied. They
also build the alias gem inside that worktree — building is offline, so a broken
alias gemspec surfaces before a live release — and delete the artifact. Dry runs
never push either gem.

## Version Numbering

- Major: breaking changes.
- Minor: backward-compatible features.
- Patch: backward-compatible fixes.
- Prerelease: use RubyGems dot notation, such as `1.21.0.rc.0` or `1.21.0.beta.0`.

## Release Candidate Smoke Targets

Before promoting a release candidate to stable, validate it against downstream apps that exercise the generated Cypress and Playwright helpers:

- `shakacode/cypress-playwright-on-rails`: run the full gem test suite and Rails matrix.
- `shakacode/react_on_rails`: bump `react_on_rails/Gemfile.development_dependencies` and run the dummy app E2E checks.
- `shakacode/react-on-rails-demos`: bump `packages/shakacode_demo_common/shakacode_demo_common.gemspec`, then run the `basic-v16-webpack` and `basic-v16-rspack` demo E2E checks.
- Private ShakaCode production apps that already use the gem should smoke-test the release candidate before the stable release.

React on Rails source-backed demos listed on https://reactonrails.com/examples/ should be added to this list as they adopt `cypress-on-rails`.

## Troubleshooting

### Missing changelog section

Run `/update-changelog release`, `/update-changelog rc`, or:

```bash
bundle exec rake "update_changelog[1.21.0.rc.0]"
```

### RubyGems publish failure

Fix authentication or OTP issues, then retry from the same checkout:

```bash
gem release
bundle exec rake "sync_github_release[VERSION]"
```

### Alias gem publish failure

The main release already succeeded; only the alias needs a retry:

```bash
(cd alias_gem && gem build e2e_on_rails.gemspec && gem push e2e_on_rails-VERSION.gem)
rm -f alias_gem/e2e_on_rails-VERSION.gem
```

### Version policy failure

Confirm the latest git tags and changelog headings. If the release is intentionally unusual:

```bash
RELEASE_VERSION_POLICY_OVERRIDE=true bundle exec rake release
```
