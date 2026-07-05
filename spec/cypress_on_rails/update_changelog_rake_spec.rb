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

    it "treats inline BREAKING entries as major changes" do
      changelog = "## [Unreleased]\n### Fixed\n* **BREAKING: Generator folder structure**: Changed\n"

      expect(inferred_bump_type_from_unreleased(changelog)).to eq(:major)
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

    it "infers the stable version from collapsed active rc notes" do
      Dir.mktmpdir do |repo_dir|
        init_git_repo!(repo_dir)
        run_git!("tag", "v1.20.0", chdir: repo_dir)
        run_git!("tag", "v1.21.0.rc.0", chdir: repo_dir)

        changelog = <<~CHANGELOG
          ## [Unreleased]

          ## [1.21.0.rc.0] - 2026-07-04

          ### Added
          * Feature
        CHANGELOG
        prepared_changelog = prepare_changelog_for_auto_version(changelog, repo_dir)

        expect(compute_auto_version(prepared_changelog, "release", repo_dir)).to eq("1.21.0")
      end
    end

    it "promotes an active prerelease base even when collapsed rc notes look patch-only" do
      Dir.mktmpdir do |repo_dir|
        init_git_repo!(repo_dir)
        run_git!("tag", "v1.20.0", chdir: repo_dir)
        run_git!("tag", "v1.21.0.rc.0", chdir: repo_dir)

        changelog = <<~CHANGELOG
          ## [Unreleased]

          ## [1.21.0.rc.0] - 2026-07-04

          ### Fixed
          * Stabilization fix
        CHANGELOG
        prepared_changelog = prepare_changelog_for_auto_version(changelog, repo_dir)

        expect(compute_auto_version(prepared_changelog, "release", repo_dir)).to eq("1.21.0")
      end
    end
  end

  describe "#collapse_prerelease_sections" do
    it "skips Unreleased when matching prerelease sections" do
      changelog = <<~CHANGELOG
        ## [Unreleased]

        ### Fixed
        * Unreleased fix

        ## [1.21.0.rc.0] - 2026-07-04

        ### Added
        * Feature
      CHANGELOG

      collapsed = collapse_prerelease_sections(changelog, "1.21.0", "rc")

      expect(collapsed).to include("### Fixed")
      expect(collapsed).to include("* Unreleased fix")
      expect(collapsed).to include("### Added")
      expect(collapsed).to include("* Feature")
      expect(collapsed).not_to include("## [1.21.0.rc.0]")
    end

    it "preserves warning labels when merging breaking-change headings" do
      changelog = <<~CHANGELOG
        ## [Unreleased]

        ### Breaking Changes
        * Plain breaking note

        ## [1.21.0.rc.0] - 2026-07-04

        ### WARNING: Breaking Changes
        * Warning breaking note
      CHANGELOG

      collapsed = collapse_prerelease_sections(changelog, "1.21.0", "rc")

      expect(collapsed).to include("### WARNING: Breaking Changes")
      expect(collapsed).to include("* Plain breaking note")
      expect(collapsed).to include("* Warning breaking note")
      expect(collapsed).not_to include("\n### Breaking Changes\n")
    end

    it "does not merge section separators into collapsed prerelease notes" do
      changelog = <<~CHANGELOG
        ## [Unreleased]

        ---

        ## [1.21.0.rc.0] - 2026-07-04

        ### Fixed
        * RC stabilization fix

        ---

        ## [1.20.0] - 2025-10-21

        ### Fixed
        * Previous fix
      CHANGELOG

      collapsed = collapse_prerelease_sections(changelog, "1.21.0", "rc")
      unreleased_section = extract_unreleased_section(collapsed)

      expect(unreleased_section).to include("### Fixed")
      expect(unreleased_section).to include("* RC stabilization fix")
      expect(unreleased_section).not_to include("---")
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
