# Release Process

This document describes how to release a new version of cypress-playwright-on-rails.

## Prerequisites

1. Maintainer access to the repository
2. RubyGems account with publish permissions for `cypress-on-rails`
3. Clean working directory on `master` branch
4. Development dependencies installed: `bundle install`
   - Includes `gem-release` for gem management (like react_on_rails)

## Release Command

The project uses a single rake task to automate the entire release process:

```bash
rake release[VERSION,DRY_RUN]
```

### Examples

```bash
# Release version 1.19.0
rake release[1.19.0]

# Automatic patch version bump (e.g., 1.18.0 -> 1.18.1)
rake release

# Dry run to preview what would happen
rake release[1.19.0,true]
```

### What the Release Task Does

The `rake release` task will:

1. Pull latest changes from master
2. Bump the version in `lib/cypress_on_rails/version.rb`
3. Update `Gemfile.lock` via `bundle install`
4. Commit the version bump and Gemfile.lock changes
5. Create a git tag (e.g., `v1.19.0`)
6. Push the commit and tag to GitHub
7. Build and publish the gem to RubyGems (will prompt for OTP)

### Post-Release Steps

After publishing, complete these manual steps:

1. **Update CHANGELOG.md**
   ```bash
   bundle exec rake update_changelog
   git commit -a -m 'Update CHANGELOG.md'
   git push
   ```

2. **Create GitHub Release**
   - Go to the releases page: https://github.com/shakacode/cypress-playwright-on-rails/releases
   - Click on the newly created tag
   - Copy release notes from CHANGELOG.md
   - Publish the release

3. **Announce the Release** (optional)
   - Post in Slack channel
   - Tweet about the release
   - Update forum posts if needed

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (X.0.0): Breaking changes
- **MINOR** (1.X.0): New features, backwards compatible
- **PATCH** (1.19.X): Bug fixes, backwards compatible

### Examples

```bash
# Patch release (bug fixes)
rake release[1.18.1]

# Minor release (new features)
rake release[1.19.0]

# Major release (breaking changes)
rake release[2.0.0]

# Automatic patch bump
rake release
```

## Pre-Release Checklist

Before running `rake release`:

- [ ] All PRs for the release are merged
- [ ] CI is passing on master
- [ ] CHANGELOG.md has [Unreleased] section with all changes
- [ ] Major changes have been tested manually
- [ ] Documentation is up to date

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


### "Failed to push gem to RubyGems" error

Ensure you're authenticated with RubyGems:
```bash
gem signin
# Enter your RubyGems credentials
```

### Tag already exists

If you need to re-release the same version:
```bash
# Delete local tag
git tag -d v1.19.0

# Delete remote tag
git push origin :v1.19.0

# Reset to before the release commit
git reset --hard HEAD~1

# Try the release again
rake release[1.19.0]
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

# 2. Check CI is passing
# Visit: https://github.com/shakacode/cypress-playwright-on-rails/actions

# 3. Release (will handle everything automatically)
rake release[1.19.0]
# Enter your RubyGems OTP when prompted

# 4. Update the changelog
bundle exec rake update_changelog
git commit -a -m 'Update CHANGELOG.md'
git push

# 5. Create GitHub release
open "https://github.com/shakacode/cypress-playwright-on-rails/releases"
# Click on the new tag, add release notes from CHANGELOG.md

# 6. Celebrate! 🎉
```

## Notes

- The release task handles all git operations (commit, tag, push) automatically
- Always ensure CI is green before releasing
- The task will fail fast if working directory is not clean
- Failed releases can be retried after fixing issues
- Use dry run mode (`rake release[VERSION,true]`) to preview changes