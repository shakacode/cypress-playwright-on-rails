# frozen_string_literal: true

require "bundler"
require "English"
require "open3"
require "rubygems/version"
require "shellwords"
require "tempfile"
require "tmpdir"

GITHUB_REPO_SLUG_PATTERN = /\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/ unless defined?(GITHUB_REPO_SLUG_PATTERN)

def release_truthy?(value)
  [true, "true", "yes", 1, "1", "t"].include?(value.instance_of?(String) ? value.downcase : value)
end

def semver_keyword?(version_input)
  %w[patch minor major].include?(version_input.to_s.strip.downcase)
end

def sh_in_dir_for_release(dir, *shell_commands)
  Dir.chdir(dir) do
    Bundler.with_unbundled_env do
      shell_commands.flatten.each do |shell_command|
        sh(shell_command.strip)
      end
    end
  end
end

def ensure_clean_worktree!
  status = `git status --porcelain`
  return if $CHILD_STATUS.success? && status.empty?

  if $CHILD_STATUS.success?
    abort "You have uncommitted changes. Please commit or stash them before releasing."
  end

  abort "Unable to check git status. Please ensure Git is installed and this is a git checkout."
end

def github_repo_slug(gem_root)
  origin_url, status = Open3.capture2e("git", "-C", gem_root, "remote", "get-url", "origin")
  origin_url = origin_url.strip
  abort "Unable to determine git origin URL for GitHub release checks.\n\n#{origin_url}" unless status.success?

  match = origin_url.match(%r{\Agit@github\.com:(?<repo>[^/]+/[^/]+?)(?:\.git)?\z}) ||
          origin_url.match(%r{\Assh://git@github\.com/(?<repo>[^/]+/[^/]+?)(?:\.git)?\z}) ||
          origin_url.match(%r{\Ahttps://(?:[^/@]+@)?github\.com/(?<repo>[^/]+/[^/]+?)(?:\.git)?\z}) ||
          origin_url.match(%r{\Agit://github\.com/(?<repo>[^/]+/[^/]+?)(?:\.git)?\z}) ||
          origin_url.match(%r{\Agithub\.com/(?<repo>[^/]+/[^/]+?)(?:\.git)?\z})
  abort "Unable to determine GitHub repository from origin URL #{origin_url.inspect}" unless match

  repo_slug = match[:repo]
  abort "GitHub repository slug #{repo_slug.inspect} from origin URL #{origin_url.inspect} is invalid." unless repo_slug.match?(GITHUB_REPO_SLUG_PATTERN)

  repo_slug
end

def verify_gh_auth(gem_root:)
  result, status = Open3.capture2e("gh", "auth", "status")
  abort "GitHub CLI authentication required. Run `gh auth login` and retry.\n\n#{result}" unless status.success?

  repo_slug = github_repo_slug(gem_root)
  permissions_result, permissions_status = Open3.capture2e("gh", "api", "repos/#{repo_slug}", "--jq", ".permissions.push")
  abort "GitHub CLI authenticated, but failed to verify write access to #{repo_slug}.\n\n#{permissions_result}" unless permissions_status.success?
  abort "GitHub CLI authenticated, but your account/token does not have write access to #{repo_slug}." unless permissions_result.strip == "true"

  puts "GitHub CLI authenticated with write access to #{repo_slug}"
end

def current_gem_version(gem_root)
  version_file = File.join(gem_root, "lib", "cypress_on_rails", "version.rb")
  content = File.read(version_file)
  match = content.match(/VERSION\s*=\s*["']([^"']+)["']/)
  abort "Unable to read current gem version from #{version_file}" unless match

  match[1]
end

def normalize_release_version_string(version_or_tag)
  version = version_or_tag.to_s.strip
  version = version.delete_prefix("v")
  version = version.sub(/-(beta|rc)\./i, '.\1.')

  unless version.match?(/\A\d+\.\d+\.\d+(\.(beta|rc)\.\d+)?\z/i)
    abort "Failed to parse version from #{version_or_tag.inspect}. Expected 1.2.3 or 1.2.3.rc.0."
  end

  version.downcase
end

def validate_requested_version_input!(version_input)
  return if semver_keyword?(version_input)
  return if version_input.to_s.match?(/\A\d+\.\d+\.\d+(\.(beta|rc)\.\d+)?\z/i)

  abort <<~ERROR
    Invalid version argument: #{version_input.inspect}

    Use:
      - Semver bump keyword: patch, minor, or major
      - Explicit version: 1.21.0
      - Explicit prerelease: 1.21.0.rc.0
  ERROR
end

def parse_gem_version_components(gem_version)
  match = gem_version.to_s.strip.match(/\A(\d+)\.(\d+)\.(\d+)(?:\.(beta|rc)\.(\d+))?\z/i)
  abort "Unsupported gem version format: #{gem_version.inspect}" unless match

  {
    major: match[1].to_i,
    minor: match[2].to_i,
    patch: match[3].to_i,
    prerelease_type: match[4]&.downcase,
    prerelease_index: match[5]&.to_i
  }
end

def compute_target_gem_version(current_gem_version:, version_input:)
  input = version_input.to_s.strip
  return normalize_release_version_string(input) unless semver_keyword?(input)

  version = parse_gem_version_components(current_gem_version)
  case input.downcase
  when "patch"
    if version[:prerelease_type]
      "#{version[:major]}.#{version[:minor]}.#{version[:patch]}"
    else
      "#{version[:major]}.#{version[:minor]}.#{version[:patch] + 1}"
    end
  when "minor"
    "#{version[:major]}.#{version[:minor] + 1}.0"
  when "major"
    "#{version[:major] + 1}.0.0"
  end
end

def prerelease_gem_version?(gem_version)
  gem_version.to_s.match?(/\A\d+\.\d+\.\d+\.(beta|rc)\.\d+\z/i)
end

def parse_release_tag_to_gem_version(tag)
  stable_match = tag.to_s.match(/\Av(\d+\.\d+\.\d+)\z/)
  return stable_match[1] if stable_match

  prerelease_with_dot = tag.to_s.match(/\Av(\d+\.\d+\.\d+)\.(beta|rc)\.(\d+)\z/i)
  return "#{prerelease_with_dot[1]}.#{prerelease_with_dot[2].downcase}.#{prerelease_with_dot[3]}" if prerelease_with_dot

  prerelease_with_dash = tag.to_s.match(/\Av(\d+\.\d+\.\d+)-(beta|rc)\.(\d+)\z/i)
  return "#{prerelease_with_dash[1]}.#{prerelease_with_dash[2].downcase}.#{prerelease_with_dash[3]}" if prerelease_with_dash

  nil
end

def tagged_release_gem_versions(gem_root, fetch_tags: true)
  if fetch_tags
    fetch_output, fetch_status = Open3.capture2e("git", "-C", gem_root, "fetch", "--tags", "--quiet")
    abort "Unable to fetch tags for version policy validation.\n\n#{fetch_output.strip}" unless fetch_status.success?
  end

  tags_output, tags_status = Open3.capture2e("git", "-C", gem_root, "tag", "-l", "v*")
  abort "Unable to list git tags for version policy validation.\n\n#{tags_output.strip}" unless tags_status.success?

  tags_output.lines.map(&:strip).filter_map { |tag| parse_release_tag_to_gem_version(tag) }.uniq
end

def version_bump_type(previous_stable_gem_version:, target_gem_version:)
  previous = parse_gem_version_components(previous_stable_gem_version)
  target = parse_gem_version_components(target_gem_version)

  return :major if target[:major] > previous[:major]
  return :minor if target[:major] == previous[:major] && target[:minor] > previous[:minor]
  return :patch if target[:major] == previous[:major] && target[:minor] == previous[:minor] && target[:patch] > previous[:patch]

  :none
end

def expected_bump_type_from_changelog_section(changelog_section)
  section = changelog_section.to_s
  return :major if section.match?(/^###\s+(?:WARNING:\s*)?Breaking(?:\s+Changes?)?\b/i)
  return :major if section.match?(/^\s*[-*]\s+(?:\*\*)?BREAKING\b/i)
  return :minor if section.match?(/^###\s+(Added|New\s+Features?|Features?|Enhancements?)\b/i)
  return :patch if section.match?(/^###\s+(Fixed|Fixes|Bug\s+Fixes?|Security|Improved|Changed|Deprecated|Removed)\b/i)

  nil
end

def version_policy_override_enabled?(override_flag)
  release_truthy?(override_flag) || release_truthy?(ENV.fetch("RELEASE_VERSION_POLICY_OVERRIDE", nil))
end

def handle_version_policy_violation!(message:, allow_override:)
  if allow_override
    puts "VERSION POLICY OVERRIDE enabled: #{message}"
    return
  end

  abort message
end

def extract_changelog_section(changelog_path:, version:)
  return nil unless File.exist?(changelog_path)

  lines = File.readlines(changelog_path)
  section_header = /^## \[(?:v)?#{Regexp.escape(version)}\]/
  start_index = lines.index { |line| line.match?(section_header) }
  return nil unless start_index

  end_index = ((start_index + 1)...lines.length).find { |idx| lines[idx].start_with?("## [") || lines[idx].start_with?("---") } || lines.length
  section = lines[(start_index + 1)...end_index].join.strip
  section.empty? ? nil : section
end

def validate_release_version_policy!(gem_root:, target_gem_version:, allow_override:, fetch_tags: true)
  tagged_versions = tagged_release_gem_versions(gem_root, fetch_tags: fetch_tags)
  latest_tagged_version = tagged_versions.max_by { |version| Gem::Version.new(version) }

  if latest_tagged_version && Gem::Version.new(target_gem_version) <= Gem::Version.new(latest_tagged_version)
    handle_version_policy_violation!(
      message: "Requested version #{target_gem_version} must be greater than latest tagged version #{latest_tagged_version}.",
      allow_override: allow_override
    )
  end

  if prerelease_gem_version?(target_gem_version) && latest_tagged_version
    target = parse_gem_version_components(target_gem_version)
    latest = parse_gem_version_components(latest_tagged_version)
    same_release_base = target[:major] == latest[:major] && target[:minor] == latest[:minor] && target[:patch] == latest[:patch]
    return if same_release_base && prerelease_gem_version?(latest_tagged_version)
  end

  latest_stable_version = tagged_versions.reject { |version| prerelease_gem_version?(version) }
                                         .max_by { |version| Gem::Version.new(version) }
  return unless latest_stable_version

  actual_bump_type = version_bump_type(
    previous_stable_gem_version: latest_stable_version,
    target_gem_version: target_gem_version
  )
  if actual_bump_type == :none
    handle_version_policy_violation!(
      message: "Requested version #{target_gem_version} is not a major/minor/patch bump over latest stable #{latest_stable_version}.",
      allow_override: allow_override
    )
    return if allow_override
  end

  if prerelease_gem_version?(target_gem_version)
    puts "VERSION POLICY: Skipping changelog bump-consistency check for prerelease #{target_gem_version}."
    return
  end

  changelog_section = extract_changelog_section(
    changelog_path: File.join(gem_root, "CHANGELOG.md"),
    version: target_gem_version
  )
  unless changelog_section
    puts "VERSION POLICY: No changelog content found for #{target_gem_version}; skipping changelog bump-consistency check."
    return
  end

  expected_bump_type = expected_bump_type_from_changelog_section(changelog_section)
  unless expected_bump_type
    puts "VERSION POLICY: CHANGELOG section #{target_gem_version} does not declare bump level; skipping changelog bump-consistency check."
    return
  end
  return if actual_bump_type == expected_bump_type

  handle_version_policy_violation!(
    message: "Version bump mismatch for #{target_gem_version}: CHANGELOG implies #{expected_bump_type}, but version bump is #{actual_bump_type} from #{latest_stable_version}.",
    allow_override: allow_override
  )
end

def extract_latest_changelog_version(gem_root:)
  changelog_path = File.join(gem_root, "CHANGELOG.md")
  return nil unless File.exist?(changelog_path)

  File.readlines(changelog_path).each do |line|
    match = line.match(/^## \[([^\]]+)\]/)
    next unless match
    next if match[1].casecmp("Unreleased").zero?

    return normalize_release_version_string(match[1])
  end

  nil
end

def version_tagged?(gem_root, version)
  system("git", "-C", gem_root, "rev-parse", "--verify", "--quiet", "refs/tags/v#{version}", out: File::NULL, err: File::NULL)
end

def resolve_version_input(version_input, gem_root)
  input = version_input.to_s.strip
  return input unless input.empty?

  changelog_version = extract_latest_changelog_version(gem_root: gem_root)
  current_version = current_gem_version(gem_root)

  if changelog_version && Gem::Version.new(changelog_version) > Gem::Version.new(current_version)
    puts "Found CHANGELOG.md version: #{changelog_version} (current: #{current_version})"
    return changelog_version
  end

  if changelog_version == current_version && !version_tagged?(gem_root, changelog_version)
    puts "Using current CHANGELOG.md version: #{changelog_version} (untagged retry)"
    return changelog_version
  end

  puts "No new version found in CHANGELOG.md (latest: #{changelog_version || 'none'}, current: #{current_version})."
  puts "Falling back to patch bump."
  "patch"
end

def warn_changelog_missing(gem_root:, version:)
  section = extract_changelog_section(changelog_path: File.join(gem_root, "CHANGELOG.md"), version: version)
  return if section

  puts "WARNING: No CHANGELOG.md section found for #{version}."
  puts "Run /update-changelog before releasing so GitHub release notes can be created automatically."
end

def ensure_git_tag_exists!(gem_root:, tag:)
  fetch_output, fetch_status = Open3.capture2e("git", "-C", gem_root, "fetch", "--tags", "--quiet")
  abort "Unable to fetch git tags before verifying #{tag.inspect}.\n\n#{fetch_output.strip}" unless fetch_status.success?

  tag_exists = system("git", "-C", gem_root, "rev-parse", "--verify", "--quiet", "refs/tags/#{tag}", out: File::NULL, err: File::NULL)
  abort "Git tag #{tag.inspect} was not found locally or remotely. Verify the tag exists before syncing GitHub release." unless tag_exists
end

def github_release_command(gem_root: nil, release_context:, notes_file_path:, probe_existing: true)
  create_command = [
    "gh", "release", "create", release_context[:tag], "--verify-tag",
    "--title", release_context[:title], "--notes-file", notes_file_path
  ]
  create_command << "--prerelease" if release_context[:prerelease]
  return create_command unless probe_existing

  abort "Internal error: github_release_command requires gem_root when probe_existing is true." unless gem_root

  release_exists = system("gh", "release", "view", release_context[:tag], chdir: gem_root, out: File::NULL, err: File::NULL)
  abort "Unable to run `gh`. Ensure GitHub CLI is installed and on PATH." if release_exists.nil?

  if release_exists
    ["gh", "release", "edit", release_context[:tag], "--title", release_context[:title],
     "--notes-file", notes_file_path, "--prerelease=#{release_context[:prerelease]}"]
  else
    create_command
  end
end

def sync_github_release_after_publish(gem_root:, gem_version:, dry_run:, changelog_section: nil)
  section = changelog_section || extract_changelog_section(
    changelog_path: File.join(gem_root, "CHANGELOG.md"),
    version: gem_version
  )

  unless section
    puts "Skipping GitHub release: no CHANGELOG.md section for #{gem_version}."
    puts "After adding the changelog section, run:"
    puts "bundle exec rake \"sync_github_release[#{gem_version}]\""
    return
  end

  release_context = {
    notes: section,
    prerelease: prerelease_gem_version?(gem_version),
    tag: "v#{gem_version}",
    title: "v#{gem_version}"
  }

  publish_or_update_github_release(gem_root: gem_root, release_context: release_context, dry_run: dry_run)
end

def publish_or_update_github_release(gem_root:, release_context:, dry_run:)
  ensure_git_tag_exists!(gem_root: gem_root, tag: release_context[:tag])

  if dry_run
    preview_command = github_release_command(
      release_context: release_context,
      notes_file_path: "release-notes-file",
      probe_existing: false
    )
    puts "DRY RUN: Would create or update GitHub release #{release_context[:tag]}#{release_context[:prerelease] ? ' (prerelease)' : ''}"
    puts "DRY RUN: Would run: #{Shellwords.join(preview_command)}"
    return
  end

  Tempfile.create(["cypress-on-rails-release-notes-", ".md"]) do |tmp|
    tmp.write(release_context[:notes])
    tmp.flush

    release_command = github_release_command(
      gem_root: gem_root,
      release_context: release_context,
      notes_file_path: tmp.path
    )

    puts "Publishing GitHub release #{release_context[:tag]}#{release_context[:prerelease] ? ' (prerelease)' : ''}"
    success = system(*release_command, chdir: gem_root)
    abort "Failed to publish GitHub release #{release_context[:tag]}." unless success
  end
end

def with_release_checkout(gem_root:, dry_run:)
  return yield(gem_root) unless dry_run

  Dir.mktmpdir("cypress-on-rails-release-dry-run") do |tmpdir|
    worktree_dir = File.join(tmpdir, "worktree")
    escaped_worktree_dir = Shellwords.escape(worktree_dir)

    sh_in_dir_for_release(gem_root, "git worktree add --detach #{escaped_worktree_dir} HEAD")
    begin
      yield(worktree_dir)
    ensure
      original_error = $ERROR_INFO
      begin
        sh_in_dir_for_release(gem_root, "git worktree remove --force #{escaped_worktree_dir}")
      rescue Exception => cleanup_error # rubocop:disable Lint/RescueException
        warn "Failed to remove dry-run release worktree #{worktree_dir}: #{cleanup_error.message}"
        raise cleanup_error unless original_error
      end
    end
  end
end

def release_staged_files
  [
    "lib/cypress_on_rails/version.rb"
  ]
end

def print_release_summary(release_result)
  released_version = release_result[:released_gem_version]
  dry_run = release_result[:dry_run]
  changelog_section_found = release_result[:changelog_section_found]

  puts "\n#{'=' * 80}"
  puts(dry_run ? "DRY RUN COMPLETE" : "RELEASE COMPLETE")
  puts "=" * 80

  if dry_run
    puts "Version would be bumped to: #{released_version}"
    puts "Files that would be updated:"
    release_result.fetch(:staged_files, []).each { |file| puts "  - #{file}" }
    puts "Changelog: #{changelog_section_found ? 'CHANGELOG.md section found' : 'No CHANGELOG.md section found'}"
    puts "To actually release, run: bundle exec rake \"release[#{released_version}]\""
  else
    puts "Published cypress-on-rails #{released_version} to RubyGems."
    puts(changelog_section_found ? "GitHub release synced from CHANGELOG.md." : "GitHub release not synced because CHANGELOG.md section was missing.")
  end
end

def perform_release(gem_version:, dry_run:, check_uncommitted: true, allow_version_policy_override: false)
  ensure_clean_worktree! if check_uncommitted
  gem_root = File.expand_path("..", __dir__)
  released_gem_version = nil
  changelog_section_found = false
  staged_files = release_staged_files

  verify_gh_auth(gem_root: gem_root) unless dry_run

  raw_version_input = gem_version.to_s.strip
  validate_requested_version_input!(raw_version_input) unless raw_version_input.empty?

  with_release_checkout(gem_root: gem_root, dry_run: dry_run) do |release_root|
    sh_in_dir_for_release(release_root, "git pull --rebase") unless dry_run

    version_input = resolve_version_input(raw_version_input, release_root)
    validate_requested_version_input!(version_input)
    current_version = current_gem_version(release_root)
    target_version = compute_target_gem_version(current_gem_version: current_version, version_input: version_input)
    version_already_current = target_version == current_version

    warn_changelog_missing(gem_root: release_root, version: target_version)
    validate_release_version_policy!(
      gem_root: release_root,
      target_gem_version: target_version,
      allow_override: allow_version_policy_override,
      fetch_tags: true
    )

    unless version_already_current
      sh_in_dir_for_release(
        release_root,
        "gem bump --no-commit --file lib/cypress_on_rails/version.rb --version #{Shellwords.escape(target_version)}"
      )
      sh_in_dir_for_release(release_root, "bundle install")
    end

    actual_version = current_gem_version(release_root)
    released_gem_version = actual_version
    abort "Expected gem bump to produce #{target_version}, but found #{actual_version}." unless actual_version == target_version

    if dry_run
      if version_already_current
        puts "DRY RUN: Would tag v#{actual_version}, push, and release gem from the current commit."
      else
        puts "DRY RUN: Would commit #{staged_files.join(', ')}, tag v#{actual_version}, push, and release gem."
      end
    else
      unless version_already_current
        sh_in_dir_for_release(release_root, "git add #{Shellwords.join(staged_files)}")
        sh_in_dir_for_release(release_root, "git commit -m #{Shellwords.escape("Release v#{actual_version}")}")
      end
      sh_in_dir_for_release(release_root, "git tag v#{actual_version}")
      sh_in_dir_for_release(release_root, "git push && git push --tags")
      puts "Carefully add your OTP for RubyGems. If you get an error, run 'gem release' again."
      sh_in_dir_for_release(release_root, "gem release")
    end
  end

  if released_gem_version
    changelog_section = extract_changelog_section(
      changelog_path: File.join(gem_root, "CHANGELOG.md"),
      version: released_gem_version
    )
    changelog_section_found = !changelog_section.nil?

    sync_github_release_after_publish(
      gem_root: gem_root,
      gem_version: released_gem_version,
      dry_run: dry_run,
      changelog_section: changelog_section
    ) unless dry_run
  end

  {
    dry_run: dry_run,
    released_gem_version: released_gem_version,
    changelog_section_found: changelog_section_found,
    staged_files: staged_files
  }
end

desc("Releases the gem using the given version.

Recommended flow:
  1. Run /update-changelog release, /update-changelog rc, or an explicit version.
  2. Merge the changelog PR.
  3. Run bundle exec rake release with no args; it reads the version from CHANGELOG.md.

Arguments:
1st argument: Version in RubyGems format (1.21.0 or 1.21.0.rc.0), semver keyword
              (patch/minor/major), or blank to use CHANGELOG.md then fall back to patch.
2nd argument: Dry run when 'true'.
3rd argument: Override version policy checks when 'true' or RELEASE_VERSION_POLICY_OVERRIDE=true.

Examples:
  bundle exec rake release
  bundle exec rake \"release[1.21.0.rc.0]\"
  bundle exec rake \"release[,true]\"
")
task :release, %i[gem_version dry_run override_version_policy] do |_t, args|
  args_hash = args.to_hash
  is_dry_run = release_truthy?(args_hash[:dry_run])
  allow_override = version_policy_override_enabled?(args_hash[:override_version_policy])

  release_result = perform_release(
    gem_version: args_hash[:gem_version].to_s,
    dry_run: is_dry_run,
    allow_version_policy_override: allow_override
  )
  print_release_summary(release_result)
end

desc("Creates or updates the GitHub release from CHANGELOG.md for a published version.

Arguments:
1st argument: Version in RubyGems format. Defaults to current lib/cypress_on_rails/version.rb.
2nd argument: Dry run when 'true'.
")
task :sync_github_release, %i[gem_version dry_run] do |_t, args|
  gem_root = File.expand_path("..", __dir__)
  version = args[:gem_version].to_s.strip
  version = current_gem_version(gem_root) if version.empty?
  validate_requested_version_input!(version)

  dry_run = release_truthy?(args[:dry_run])
  verify_gh_auth(gem_root: gem_root) unless dry_run
  sync_github_release_after_publish(gem_root: gem_root, gem_version: normalize_release_version_string(version), dry_run: dry_run)
end
