# frozen_string_literal: true

# Thin wrapper gem that reserves `e2e_on_rails`, the canonical gem name this
# project adopts at 2.0. See ../docs/adr/0001-reserve-e2e_on_rails-rename-at-2.0.md
# and ../docs/adr/0002-public-rebrand-e2e-on-rails.md.
#
# The version and the dependency requirement are both derived from the parent
# gem's lib/cypress_on_rails/version.rb so the two gems can never drift.
alias_gem_root = __dir__

# RubyGems resolves `spec.files` against the current directory, not against the
# gemspec's directory. Building from the repository root would therefore package
# the parent repository's README.md instead of this one, so fail loudly instead.
unless File.identical?(Dir.pwd, alias_gem_root)
  raise "Build this gem from its own directory: " \
        "(cd #{File.basename(alias_gem_root)} && gem build e2e_on_rails.gemspec). " \
        "RubyGems resolves spec.files relative to the current directory " \
        "(#{Dir.pwd}), which would package the wrong files."
end

parent_version_file = File.expand_path("../lib/cypress_on_rails/version.rb", alias_gem_root)
parent_version_match = File.read(parent_version_file).match(/VERSION\s*=\s*["']([^"']+)["']/)
raise "Unable to read CypressOnRails::VERSION from #{parent_version_file}" unless parent_version_match

parent_version = parent_version_match[1]
parent_major, parent_minor = parent_version.split(".")
repo_uri = "https://github.com/shakacode/cypress-playwright-on-rails"
adr_uri = "#{repo_uri}/blob/master/docs/adr/0001-reserve-e2e_on_rails-rename-at-2.0.md"

Gem::Specification.new do |spec|
  spec.name        = "e2e_on_rails"
  spec.version     = parent_version
  spec.authors     = ["miceportal team", "Grant Petersen-Speelman"]
  spec.email       = ["info@miceportal.de", "grantspeelman@gmail.com"]
  spec.license     = "MIT"
  spec.homepage    = "https://e2eonrails.com"
  spec.summary     = "E2E on Rails: the Rails test bridge for Cypress and Playwright " \
                     "(alias gem; canonical at 2.0)"
  spec.description = "Alias gem that reserves e2e_on_rails, the canonical name this project adopts " \
                     "at 2.0, and installs the matching cypress-on-rails version. It ships no code " \
                     "of its own: require 'e2e_on_rails' simply requires 'cypress_on_rails'. Use " \
                     "cypress-on-rails directly if you are unsure. Rationale: ADR-0001, #{adr_uri}"

  # This directory's own files only; never glob the parent repository.
  spec.files = Dir["lib/**/*.rb"].sort + ["README.md"]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "bug_tracker_uri"   => "#{repo_uri}/issues",
    "changelog_uri"     => "#{repo_uri}/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://e2eonrails.com",
    "homepage_uri"      => "https://e2eonrails.com",
    "source_code_uri"   => repo_uri
  }

  spec.add_dependency "cypress-on-rails", "~> #{parent_major}.#{parent_minor}"
end
