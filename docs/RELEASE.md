# Release Process

Release notes are prepared before publishing.

1. Run `/update-changelog release`, `/update-changelog rc`, or `/update-changelog VERSION`.
2. Merge the changelog PR.
3. From a clean, current `master`, run:

```bash
bundle exec rake release
```

The release task reads the newest stamped `CHANGELOG.md` version, bumps the gem version, commits, tags, pushes, publishes to RubyGems, and syncs the GitHub release from the changelog section.

Useful variants:

```bash
bundle exec rake "release[,true]"          # dry run
bundle exec rake "release[1.21.0.rc.0]"    # explicit version
bundle exec rake "sync_github_release[1.21.0.rc.0]"
```

Prereleases use RubyGems dot notation, for example `1.21.0.rc.0`.
