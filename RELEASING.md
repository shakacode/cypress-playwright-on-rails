# Release Process

This document describes how to release a new version of cypress-playwright-on-rails.

## Prerequisites

1. Maintainer access to the repository
2. RubyGems account with publish permissions for `cypress-on-rails`
3. Clean working directory on `master` branch
4. Development dependencies installed: `bundle install`
   - Includes `gem-release` for gem management (like react_on_rails)

## Release Tasks

The project uses rake tasks with `gem-release` to automate the release process (similar to react_on_rails and other ShakaCode gems):

### Quick Release

```bash
# Prepare and publish in one command
rake release:prepare[1.19.0]
# Review changes, commit
rake release:publish
```

### Step-by-Step Release

#### 1. Prepare the Release

```bash
rake release:prepare[1.19.0]
```

This task will:
- Validate the version format (X.Y.Z)
- Use `gem bump` to update `lib/cypress_on_rails/version.rb`
- Update `CHANGELOG.md` with the new version and date
- Provide next steps

After running this:
```bash
# Review the changes
git diff

# Commit the version bump
git add -A
git commit -m "Bump version to 1.19.0"

# Push to master
git push origin master
```

#### 2. Publish the Release

```bash
rake release:publish
```

This task will:
- Verify you're on master branch
- Verify working directory is clean
- Run the test suite
- Use `gem release` to:
  - Build the gem
  - Push the gem to RubyGems
  - Create a git tag (e.g., `v1.19.0`)
  - Push the tag to GitHub

#### 3. Post-Release Steps

After publishing, complete these manual steps:

1. **Create GitHub Release**
   - Go to https://github.com/shakacode/cypress-playwright-on-rails/releases/new?tag=v1.19.0
   - Copy release notes from CHANGELOG.md
   - Publish the release

2. **Announce the Release**
   - Post in Slack channel
   - Tweet about the release
   - Update forum posts if needed

3. **Close Related Issues**
   - Review issues addressed in this release
   - Close them with reference to the release

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (X.0.0): Breaking changes
- **MINOR** (1.X.0): New features, backwards compatible
- **PATCH** (1.19.X): Bug fixes, backwards compatible

### Examples

```bash
# Patch release (bug fixes)
rake release:prepare[1.18.1]

# Minor release (new features)
rake release:prepare[1.19.0]

# Major release (breaking changes)
rake release:prepare[2.0.0]
```

## Pre-Release Checklist

Before running `rake release:prepare`:

- [ ] All PRs for the release are merged
- [ ] CI is passing on master
- [ ] CHANGELOG.md has [Unreleased] section with all changes
- [ ] Major changes have been tested manually
- [ ] Documentation is up to date
- [ ] Issue #183 discussion is resolved (if applicable)

## Troubleshooting

### "Must be on master branch" error

```bash
git checkout master
git pull --rebase
```

### "Working directory is not clean" error

```bash
# Commit or stash your changes
git status
git add -A && git commit -m "Your message"
# or
git stash
```

### "Tests failed" error

```bash
# Fix the failing tests before releasing
bundle exec rake spec

# If tests are truly failing, don't release
```

### "Failed to push gem to RubyGems" error

Ensure you're authenticated with RubyGems:
```bash
gem signin
# Enter your RubyGems credentials
```

### Tag already exists

If you need to re-release:
```bash
# Delete local tag
git tag -d v1.19.0

# Delete remote tag
git push origin :v1.19.0

# Try again
rake release:publish
```

## Rollback

If you need to rollback a release:

### Yank the gem from RubyGems
```bash
gem yank cypress-on-rails -v 1.19.0
```

### Delete the git tag
```bash
git tag -d v1.19.0
git push origin :v1.19.0
```

### Revert the version commit
```bash
git revert HEAD
git push origin master
```

## Example Release Flow

```bash
# 1. Ensure you're on master and up to date
git checkout master
git pull --rebase

# 2. Prepare the release
rake release:prepare[1.19.0]
# Review output, confirm with 'y'

# 3. Review and commit changes
git diff
git add -A
git commit -m "Bump version to 1.19.0"

# 4. Run tests (optional, publish will run them too)
bundle exec rake spec

# 5. Push to master
git push origin master

# 6. Publish the release
rake release:publish

# 7. Create GitHub release
open "https://github.com/shakacode/cypress-playwright-on-rails/releases/new?tag=v1.19.0"

# 8. Celebrate! 🎉
```

## Notes

- The release tasks will **not** push commits to master for you
- Always review changes before committing
- The `publish` task will run tests before releasing
- Tags are created locally first, then pushed
- Failed releases can be retried after fixing issues