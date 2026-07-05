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
