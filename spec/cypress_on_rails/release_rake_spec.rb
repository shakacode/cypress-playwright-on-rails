# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"
require "rake"
require "stringio"
require "tmpdir"

RSpec.describe "release rake helpers" do
  before(:all) do
    load File.expand_path("../../rakelib/release.rake", __dir__)
  end

  def capture_stdout
    original_stdout = $stdout
    output = StringIO.new
    $stdout = output
    yield
    output.string
  ensure
    $stdout = original_stdout
  end

  describe "#parse_release_tag_to_gem_version" do
    it "parses stable and prerelease tags" do
      expect(parse_release_tag_to_gem_version("v1.21.0")).to eq("1.21.0")
      expect(parse_release_tag_to_gem_version("v1.21.0.rc.1")).to eq("1.21.0.rc.1")
      expect(parse_release_tag_to_gem_version("v1.21.0-rc.1")).to eq("1.21.0.rc.1")
    end
  end

  describe "#compute_target_gem_version" do
    it "computes semver keyword bumps" do
      expect(compute_target_gem_version(current_gem_version: "1.20.3", version_input: "patch")).to eq("1.20.4")
      expect(compute_target_gem_version(current_gem_version: "1.20.3", version_input: "minor")).to eq("1.21.0")
      expect(compute_target_gem_version(current_gem_version: "1.20.3", version_input: "major")).to eq("2.0.0")
    end

    it "promotes prereleases to stable with patch" do
      expect(compute_target_gem_version(current_gem_version: "1.21.0.rc.0", version_input: "patch")).to eq("1.21.0")
    end

    it "passes explicit versions through unchanged" do
      expect(compute_target_gem_version(current_gem_version: "1.20.0", version_input: "1.21.0.rc.0"))
        .to eq("1.21.0.rc.0")
    end
  end

  describe "#extract_latest_changelog_version" do
    it "reads the first versioned changelog header after Unreleased" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "CHANGELOG.md"), <<~CHANGELOG)
          # Changelog

          ## [Unreleased]

          ## [1.21.0.rc.0] - 2026-07-04
          ### Fixed
          * Fix
        CHANGELOG

        expect(extract_latest_changelog_version(gem_root: dir)).to eq("1.21.0.rc.0")
      end
    end
  end

  describe "#release_staged_files" do
    it "stages only tracked release metadata" do
      expect(release_staged_files).to eq(["lib/cypress_on_rails/version.rb"])
    end
  end

  describe "#perform_release" do
    it "pulls the release checkout before resolving a blank version input" do
      events = []

      allow(self).to receive(:ensure_clean_worktree!)
      allow(self).to receive(:verify_gh_auth)
      allow(self).to receive(:with_release_checkout)
        .with(gem_root: File.expand_path("../..", __dir__), dry_run: false)
        .and_yield("/fresh")
      allow(self).to receive(:extract_latest_changelog_version)
        .with(gem_root: "/fresh")
        .and_return("1.21.0")
      allow(self).to receive(:current_gem_version)
        .with("/fresh")
        .and_return("1.20.0", "1.20.0", "1.21.0")
      allow(self).to receive(:warn_changelog_missing)
      allow(self).to receive(:validate_release_version_policy!)
      allow(self).to receive(:sync_github_release_after_publish)
      allow(self).to receive(:sh_in_dir_for_release) do |_dir, command|
        events << command
      end

      result = nil
      capture_stdout { result = perform_release(gem_version: "", dry_run: false) }
      bump_command = events.find { |command| command.include?("gem bump") }

      expect(result[:released_gem_version]).to eq("1.21.0")
      expect(events).to include("git pull --rebase")
      expect(bump_command).to include("--version 1.21.0")
      expect(events.index("git pull --rebase")).to be < events.index(bump_command)
    end

    it "tags and publishes the current commit for an untagged retry" do
      events = []

      allow(self).to receive(:ensure_clean_worktree!)
      allow(self).to receive(:verify_gh_auth)
      allow(self).to receive(:with_release_checkout)
        .with(gem_root: File.expand_path("../..", __dir__), dry_run: false)
        .and_yield("/fresh")
      allow(self).to receive(:extract_latest_changelog_version)
        .with(gem_root: "/fresh")
        .and_return("1.21.0")
      allow(self).to receive(:current_gem_version)
        .with("/fresh")
        .and_return("1.21.0", "1.21.0", "1.21.0")
      allow(self).to receive(:version_tagged?).with("/fresh", "1.21.0").and_return(false)
      allow(self).to receive(:warn_changelog_missing)
      allow(self).to receive(:validate_release_version_policy!)
      allow(self).to receive(:sync_github_release_after_publish)
      allow(self).to receive(:sh_in_dir_for_release) do |_dir, command|
        events << command
      end

      result = nil
      capture_stdout { result = perform_release(gem_version: "", dry_run: false) }

      expect(result[:released_gem_version]).to eq("1.21.0")
      expect(events.grep(/gem bump/)).to be_empty
      expect(events.grep(/git commit/)).to be_empty
      expect(events).to include("git tag v1.21.0")
      expect(events).to include("git push && git push --tags")
      expect(events).to include("gem release")
    end
  end

  describe "#resolve_version_input" do
    it "uses the changelog version when it is newer than the current gem version" do
      allow(self).to receive(:extract_latest_changelog_version).with(gem_root: "/repo").and_return("1.21.0.rc.0")
      allow(self).to receive(:current_gem_version).with("/repo").and_return("1.20.0")

      result = nil
      capture_stdout { result = resolve_version_input("", "/repo") }

      expect(result).to eq("1.21.0.rc.0")
    end

    it "uses the current changelog version when it matches the gem version and is untagged" do
      allow(self).to receive(:extract_latest_changelog_version).with(gem_root: "/repo").and_return("1.21.0.rc.0")
      allow(self).to receive(:current_gem_version).with("/repo").and_return("1.21.0.rc.0")
      allow(self).to receive(:version_tagged?).with("/repo", "1.21.0.rc.0").and_return(false)

      result = nil
      capture_stdout { result = resolve_version_input("", "/repo") }

      expect(result).to eq("1.21.0.rc.0")
    end

    it "falls back to patch when the matching changelog version is already tagged" do
      allow(self).to receive(:extract_latest_changelog_version).with(gem_root: "/repo").and_return("1.20.0")
      allow(self).to receive(:current_gem_version).with("/repo").and_return("1.20.0")
      allow(self).to receive(:version_tagged?).with("/repo", "1.20.0").and_return(true)

      result = nil
      capture_stdout { result = resolve_version_input("", "/repo") }

      expect(result).to eq("patch")
    end
  end

  describe "#expected_bump_type_from_changelog_section" do
    it "infers bump shape from changelog headings" do
      expect(expected_bump_type_from_changelog_section("### Breaking Changes\n* Break")).to eq(:major)
      expect(expected_bump_type_from_changelog_section("### Added\n* Feature")).to eq(:minor)
      expect(expected_bump_type_from_changelog_section("### Fixed\n* Fix")).to eq(:patch)
    end

    it "treats inline BREAKING entries as major changes" do
      expect(expected_bump_type_from_changelog_section("### Fixed\n* **BREAKING: Generator folder structure**: Changed")).to eq(:major)
    end
  end

  describe "#validate_release_version_policy!" do
    it "allows stable promotion of an active prerelease even when notes look patch-only" do
      allow(self).to receive(:tagged_release_gem_versions)
        .with("/repo", fetch_tags: false)
        .and_return(["1.20.0", "1.21.0.rc.0"])
      allow(self).to receive(:extract_changelog_section)
        .with(changelog_path: "/repo/CHANGELOG.md", version: "1.21.0")
        .and_return("### Fixed\n* Stabilization fix")

      expect do
        capture_stdout do
          validate_release_version_policy!(
            gem_root: "/repo",
            target_gem_version: "1.21.0",
            allow_override: false,
            fetch_tags: false
          )
        end
      end.not_to raise_error
    end
  end

  describe "sync_github_release task" do
    it "rejects semver keywords with a task-specific error" do
      task = Rake::Task["sync_github_release"]
      task.reenable

      expect do
        task.invoke("patch", "true")
      end.to raise_error(SystemExit, /sync_github_release expects an explicit version/)
    end
  end

  describe "#perform_sync_github_release" do
    it "defaults to the current gem version for dry runs without checking GitHub auth" do
      allow(self).to receive(:current_gem_version).with("/repo").and_return("1.20.0")
      expect(self).not_to receive(:verify_gh_auth)
      expect(self).to receive(:sync_github_release_after_publish)
        .with(gem_root: "/repo", gem_version: "1.20.0", dry_run: true)

      perform_sync_github_release(gem_root: "/repo", version_input: "", dry_run: true)
    end
  end

  describe "#extract_changelog_section" do
    it "extracts body text for the requested version without including adjacent sections" do
      Dir.mktmpdir do |dir|
        changelog_path = File.join(dir, "CHANGELOG.md")
        File.write(changelog_path, <<~CHANGELOG)
          # Changelog

          ## [Unreleased]

          ## [1.21.0] - 2026-07-04
          ### Fixed
          * New fix

          ## [1.20.0] - 2025-10-21
          ### Changed
          * Old change
        CHANGELOG

        section = extract_changelog_section(changelog_path: changelog_path, version: "1.21.0")

        expect(section).to include("* New fix")
        expect(section).not_to include("## [1.21.0]")
        expect(section).not_to include("* Old change")
      end
    end

    it "returns nil when the section has no release notes" do
      Dir.mktmpdir do |dir|
        changelog_path = File.join(dir, "CHANGELOG.md")
        File.write(changelog_path, <<~CHANGELOG)
          ## [Unreleased]

          ## [1.21.0] - 2026-07-04

          ## [1.20.0] - 2025-10-21
          ### Fixed
          * Old fix
        CHANGELOG

        expect(extract_changelog_section(changelog_path: changelog_path, version: "1.21.0")).to be_nil
      end
    end

    it "returns nil when the changelog file is missing" do
      Dir.mktmpdir do |dir|
        expect(extract_changelog_section(changelog_path: File.join(dir, "CHANGELOG.md"), version: "1.21.0"))
          .to be_nil
      end
    end
  end

  describe "#github_repo_slug" do
    def stub_origin_url(url, success: true)
      status = instance_double(Process::Status, success?: success)
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/repo", "remote", "get-url", "origin")
        .and_return(["#{url}\n", status])
    end

    it "extracts slugs from common GitHub remote URL formats" do
      {
        "git@github.com:shakacode/cypress-playwright-on-rails.git" => "shakacode/cypress-playwright-on-rails",
        "ssh://git@github.com/shakacode/cypress-playwright-on-rails.git" => "shakacode/cypress-playwright-on-rails",
        "https://github.com/shakacode/cypress-playwright-on-rails.git" => "shakacode/cypress-playwright-on-rails",
        "github.com/shakacode/cypress-playwright-on-rails" => "shakacode/cypress-playwright-on-rails"
      }.each do |origin_url, expected_slug|
        stub_origin_url(origin_url)

        expect(github_repo_slug("/repo")).to eq(expected_slug)
      end
    end
  end

  describe "#with_release_checkout" do
    before do
      allow(Dir).to receive(:mktmpdir)
        .with("cypress-on-rails-release-dry-run")
        .and_yield("/tmp/cypress-on-rails-release")
    end

    it "preserves release failures when dry-run worktree cleanup also fails" do
      allow(self).to receive(:sh_in_dir_for_release) do |_dir, command|
        raise "cleanup failed" if command.include?("git worktree remove")
      end

      expect do
        expect do
          with_release_checkout(gem_root: "/repo", dry_run: true) { raise "release failed" }
        end.to raise_error(RuntimeError, "release failed")
      end.to output(/Failed to remove dry-run release worktree/).to_stderr
    end
  end
end
