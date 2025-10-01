# Release Process

This document describes how to release a new version of the `cypress-on-rails` gem.

## Prerequisites

1. Install the `gem-release` gem globally:
   ```bash
   gem install gem-release
   ```

2. Ensure you have write access to the rubygems.org package

3. Set up two-factor authentication (2FA) for RubyGems and have your OTP generator ready

## Release Steps

### 1. Prepare for Release

Ensure your working directory is clean:
```bash
git status
```

If you have uncommitted changes, commit or stash them first.

### 2. Pull Latest Changes

```bash
git pull --rebase
```

### 3. Run the Release Task

To release a specific version:
```bash
rake release[1.19.0]
```

To automatically bump the patch version:
```bash
rake release
```

To perform a dry run (without actually publishing):
```bash
rake release[1.19.0,true]
```

### 4. Enter Your OTP

When prompted, enter your one-time password (OTP) from your authenticator app for RubyGems.

If you get an error during gem publishing, you can run `gem release` manually to retry.

### 5. Update the CHANGELOG

After successfully publishing the gem, update the CHANGELOG:

```bash
bundle exec rake update_changelog
git commit -a -m 'Update CHANGELOG.md'
git push
```

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **Major version** (X.0.0): Breaking changes
- **Minor version** (0.X.0): New features, backwards compatible
- **Patch version** (0.0.X): Bug fixes, backwards compatible
- **Pre-release versions**: Use dot notation, not dashes (e.g., `2.0.0.beta.1`, not `2.0.0-beta.1`)

## What the Release Task Does

The release task automates the following steps:

1. Checks for uncommitted changes (will abort if found)
2. Pulls the latest changes from the repository
3. Bumps the version number in `lib/cypress_on_rails/version.rb`
4. Creates a git commit with the version bump
5. Creates a git tag for the new version
6. Pushes the commit and tag to GitHub
7. Builds the gem
8. Publishes the gem to RubyGems

## Troubleshooting

### Authentication Error

If you get an authentication error with RubyGems:
1. Verify your OTP is correct and current
2. Ensure your RubyGems API key is valid
3. Run `gem release` manually to retry

### Version Already Exists

If the version already exists on RubyGems:
1. Bump to a higher version number
2. Or fix the version in `lib/cypress_on_rails/version.rb` and try again

### Uncommitted Changes Error

If you have uncommitted changes:
1. Review your changes with `git status`
2. Commit them with `git commit -am "Your message"`
3. Or stash them with `git stash`
4. Then retry the release

## Post-Release

After releasing:

1. Announce the release on relevant channels (Slack, forum, etc.)
2. Update any documentation that references version numbers
3. Consider creating a GitHub release with release notes
