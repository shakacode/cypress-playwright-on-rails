# frozen_string_literal: true

require "English"

desc "Updates CHANGELOG.md inserting headers for the new version.

Argument: Git tag. Defaults to the latest tag."

task :update_changelog, %i[tag] do |_, args|
  tag = args[:tag] || `git describe --tags --abbrev=0`.strip

  # Remove 'v' prefix if present (e.g., v1.18.0 -> 1.18.0)
  version = tag.start_with?('v') ? tag[1..-1] : tag
  anchor = "[#{version}]"

  changelog = File.read("CHANGELOG.md")

  if changelog.include?(anchor)
    puts "Tag #{version} is already documented in CHANGELOG.md, update manually if needed"
    next
  end

  tag_date_output = `git show -s --format=%cs #{tag} 2>&1`
  if $CHILD_STATUS.success?
    tag_date = tag_date_output.split("\n").last.strip
  else
    abort("Failed to find tag #{tag}")
  end

  # After "## [Unreleased]", insert new version header
  unreleased_section = "## [Unreleased]"
  new_version_header = "\n\n## #{anchor} - #{tag_date}"

  if changelog.include?(unreleased_section)
    changelog.sub!(unreleased_section, "#{unreleased_section}#{new_version_header}")
  else
    abort("Could not find '## [Unreleased]' section in CHANGELOG.md")
  end

  # Find and update version comparison links at the bottom
  # Pattern: [1.18.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.17.0...v1.18.0
  compare_link_prefix = "https://github.com/shakacode/cypress-playwright-on-rails/compare"

  # Find the last version link to determine the previous version
  last_version_match = changelog.match(/\[(\d+\.\d+\.\d+(?:\.\w+)?)\]:.*?compare\/v(\d+\.\d+\.\d+(?:\.\w+)?)\.\.\.v(\d+\.\d+\.\d+(?:\.\w+)?)/)

  if last_version_match
    last_version = last_version_match[1]
    # Add new version link at the top of the version list
    new_link = "#{anchor}: #{compare_link_prefix}/v#{last_version}...v#{version}"
    # Insert after the "<!-- Version diff reference list -->" comment
    changelog.sub!("<!-- Version diff reference list -->", "<!-- Version diff reference list -->\n#{new_link}")
  else
    puts "Warning: Could not find version comparison links. You may need to add the link manually."
  end

  File.write("CHANGELOG.md", changelog)
  puts "Updated CHANGELOG.md with an entry for #{version}"
  puts "\nNext steps:"
  puts "1. Edit CHANGELOG.md to add release notes under the [#{version}] section"
  puts "2. Move content from [Unreleased] to [#{version}] if applicable"
  puts "3. Review and commit the changes"
end
