# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rake"
require "tmpdir"

RSpec.describe "update_changelog rake helpers" do
  before(:all) do
    load File.expand_path("../../rakelib/update_changelog.rake", __dir__)
  end

  def run_git!(*args, chdir:)
    output, status = Open3.capture2e("git", *args, chdir: chdir)
    raise "git #{args.join(' ')} failed:\n#{output}" unless status.success?

    output.strip
  end

  def init_git_repo!(repo_dir)
    run_git!("init", chdir: repo_dir)
    run_git!("config", "user.email", "test@example.com", chdir: repo_dir)
    run_git!("config", "user.name", "Test User", chdir: repo_dir)
    File.write(File.join(repo_dir, "README.md"), "test\n")
    run_git!("add", "README.md", chdir: repo_dir)
    run_git!("commit", "-m", "Initial commit", chdir: repo_dir)
  end

  describe "#normalize_version_string" do
    it "normalizes stable and prerelease tags to RubyGems format" do
      expect(normalize_version_string("v1.21.0")).to eq("1.21.0")
      expect(normalize_version_string("1.21.0-rc.1")).to eq("1.21.0.rc.1")
    end
  end

  describe "#inferred_bump_type_from_unreleased" do
    it "infers major, minor, and patch from Unreleased headings" do
      expect(inferred_bump_type_from_unreleased("## [Unreleased]\n### Breaking Changes\n* Break\n")).to eq(:major)
      expect(inferred_bump_type_from_unreleased("## [Unreleased]\n### Added\n* Add\n")).to eq(:minor)
      expect(inferred_bump_type_from_unreleased("## [Unreleased]\n### Fixed\n* Fix\n")).to eq(:patch)
    end
  end

  describe "#compute_auto_version" do
    it "computes the next rc version using git tags for the prerelease index" do
      Dir.mktmpdir do |repo_dir|
        init_git_repo!(repo_dir)
        run_git!("tag", "v1.20.0", chdir: repo_dir)
        run_git!("tag", "v1.21.0.rc.0", chdir: repo_dir)

        changelog = <<~CHANGELOG
          ## [Unreleased]
          ### Added
          * Feature
        CHANGELOG

        expect(compute_auto_version(changelog, "rc", repo_dir)).to eq("1.21.0.rc.1")
      end
    end

    it "computes the next stable release from Unreleased headings" do
      Dir.mktmpdir do |repo_dir|
        init_git_repo!(repo_dir)
        run_git!("tag", "v1.20.0", chdir: repo_dir)

        changelog = <<~CHANGELOG
          ## [Unreleased]
          ### Fixed
          * Fix
        CHANGELOG

        expect(compute_auto_version(changelog, "release", repo_dir)).to eq("1.20.1")
      end
    end
  end

  describe "#insert_version_header" do
    it "inserts the version header after Unreleased" do
      changelog = +"## [Unreleased]\n\n### Fixed\n* Fix\n"

      expect(insert_version_header(changelog, "[1.21.0.rc.0]", "2026-07-04")).to eq(true)
      expect(changelog).to include("## [Unreleased]\n\n## [1.21.0.rc.0] - 2026-07-04")
    end
  end

  describe "#update_changelog_links" do
    it "updates an existing unreleased compare link and adds the new version link" do
      changelog = +"[unreleased]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.20.0...master\n" \
                   "[1.20.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.19.0...v1.20.0\n"

      update_changelog_links(changelog, "1.21.0", "[1.21.0]")

      expect(changelog).to include("[unreleased]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.21.0...master")
      expect(changelog).to include("[1.21.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.20.0...v1.21.0")
    end

    it "creates version links when the changelog has a reference list but no unreleased link" do
      changelog = +"## [1.20.0] - 2025-10-21\n\n<!-- Version diff reference list -->\n" \
                   "[1.19.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.18.0...v1.19.0\n"

      update_changelog_links(changelog, "1.21.0", "[1.21.0]")

      expect(changelog).to include("[unreleased]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.21.0...master")
      expect(changelog).to include("[1.21.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.20.0...v1.21.0")
      expect(changelog).to include("[1.20.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.19.0...v1.20.0")
    end
  end
end
