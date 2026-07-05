# frozen_string_literal: true

require "date"
require "English"
require "open3"
require "rubygems/version"

CHANGELOG_COMPARE_PREFIX = "https://github.com/shakacode/cypress-playwright-on-rails/compare" unless defined?(CHANGELOG_COMPARE_PREFIX)
CHANGELOG_BASE_BRANCH = "master" unless defined?(CHANGELOG_BASE_BRANCH)

def gem_root_for_changelog
  File.expand_path("..", __dir__)
end

def prerelease_version?(version)
  version.to_s.match?(/\.(beta|rc)\./i)
end

def normalize_version_string(version_or_tag)
  version = version_or_tag.to_s.strip
  version = version.delete_prefix("v")
  version = version.sub(/-(beta|rc)\./i, '.\1.')

  unless version.match?(/\A\d+\.\d+\.\d+(\.(beta|rc)\.\d+)?\z/i)
    abort "Failed to parse version from #{version_or_tag.inspect}. Expected format like 1.21.0 or 1.21.0.rc.0."
  end

  version.downcase
end

def parse_release_tag_to_version(tag)
  version_pattern = /\d+\.\d+\.\d+(?:\.(?:beta|rc)\.\d+)?|\d+\.\d+\.\d+-(?:beta|rc)\.\d+/
  tag_match = tag.to_s.strip.match(/\Av(?<version>#{version_pattern})\z/i)
  return nil unless tag_match

  normalize_version_string(tag_match[:version])
rescue SystemExit
  nil
end

def fetch_git_tags!(gem_root)
  remotes_output, remotes_status = Open3.capture2e("git", "-C", gem_root, "remote")
  abort "Failed to list git remotes.\n#{remotes_output}" unless remotes_status.success?

  remote_names = remotes_output.lines.map(&:strip).reject(&:empty?)
  return if remote_names.empty?

  remote_name = remote_names.include?("origin") ? "origin" : remote_names.first
  fetch_output, fetch_status = Open3.capture2e("git", "-C", gem_root, "fetch", remote_name, "--tags", "--quiet")
  abort "Failed to fetch git tags from #{remote_name}.\n#{fetch_output}" unless fetch_status.success?
end

def tag_versions(gem_root)
  tags_output, status = Open3.capture2e("git", "-C", gem_root, "tag", "-l", "v*")
  abort "Failed to list git tags.\n#{tags_output}" unless status.success?

  tags_output.lines.map(&:strip).filter_map { |tag| parse_release_tag_to_version(tag) }.uniq
end

def stable_tag_versions(gem_root)
  tag_versions(gem_root).reject { |version| prerelease_version?(version) }
end

def latest_stable_tag_version(gem_root)
  versions = stable_tag_versions(gem_root)
  abort "Failed to compute latest stable tag: no stable v* tags found." if versions.empty?

  versions.max_by { |version| Gem::Version.new(version) }
end

def extract_unreleased_section(changelog)
  lines = changelog.lines
  start_index = lines.index { |line| line.start_with?("## [Unreleased]") }
  abort "Failed to find '## [Unreleased]' in CHANGELOG.md" unless start_index

  end_index = ((start_index + 1)...lines.length).find { |idx| lines[idx].start_with?("## [") || lines[idx].start_with?("---") } || lines.length
  lines[start_index...end_index].join
end

def inferred_bump_type_from_unreleased(changelog)
  section = extract_unreleased_section(changelog)
  return :major if section.match?(/^###\s+(?:WARNING:\s*)?Breaking(?:\s+Changes?)?\b/i)
  return :major if section.match?(/^\s*[-*]\s+(?:\*\*)?BREAKING\b/i)
  return :minor if section.match?(/^###\s+(Added|New\s+Features?|Features?|Enhancements?)\b/i)
  return :patch if section.match?(/^###\s+(Fixed|Fixes|Bug\s+Fixes?|Security|Improved|Changed|Deprecated|Removed)\b/i)

  :patch
end

def bump_stable_version(version, bump_type)
  match = version.match(/\A(\d+)\.(\d+)\.(\d+)\z/)
  abort "Failed to bump version: stable version #{version.inspect} is invalid." unless match

  major = match[1].to_i
  minor = match[2].to_i
  patch = match[3].to_i

  case bump_type
  when :major
    "#{major + 1}.0.0"
  when :minor
    "#{major}.#{minor + 1}.0"
  else
    "#{major}.#{minor}.#{patch + 1}"
  end
end

def prerelease_indices_from_tags(gem_root, base_version, channel)
  tags_output, status = Open3.capture2e("git", "-C", gem_root, "tag", "-l", "v#{base_version}*")
  abort "Failed to list prerelease tags.\n#{tags_output}" unless status.success?

  tags_output.lines.map(&:strip).filter_map do |tag|
    normalized_version = parse_release_tag_to_version(tag)
    match = normalized_version&.match(/\A#{Regexp.escape(base_version)}\.#{channel}\.(\d+)\z/i)
    match&.captures&.first&.to_i
  end
end

def parse_changelog_sections(changelog)
  lines = changelog.lines
  headers = []
  lines.each_with_index do |line, index|
    match = line.match(/^## \[([^\]]+)\].*$/)
    headers << { index: index, version: match[1], header: line } if match
  end

  return { prefix: changelog, sections: [] } if headers.empty?

  prefix = lines[0...headers.first[:index]].join
  sections = headers.each_with_index.map do |header, section_index|
    section_end = if section_index + 1 < headers.length
                    headers[section_index + 1][:index]
                  else
                    lines.length
                  end

    {
      version: header[:version],
      header: header[:header],
      body: lines[(header[:index] + 1)...section_end].join
    }
  end

  { prefix: prefix, sections: sections }
end

def render_changelog_sections(prefix, sections)
  "#{prefix}#{sections.map { |section| "#{section[:header]}#{section[:body]}" }.join}"
end

def changelog_versions(changelog)
  parse_changelog_sections(changelog)[:sections]
    .map { |section| section[:version] }
    .reject { |version| version.casecmp("Unreleased").zero? }
    .map { |version| normalize_version_string(version) }
end

def prerelease_base_version(version)
  version.to_s.sub(/\.(beta|rc)\.\d+\z/i, "")
end

def active_prerelease_base_version(gem_root, changelog)
  latest_stable = latest_stable_tag_version(gem_root)
  prerelease_bases = (tag_versions(gem_root) + changelog_versions(changelog))
                     .uniq
                     .select { |version| prerelease_version?(version) }
                     .map { |version| prerelease_base_version(version) }
                     .select { |base_version| Gem::Version.new(base_version) > Gem::Version.new(latest_stable) }
                     .uniq

  prerelease_bases.max_by { |base_version| Gem::Version.new(base_version) }
end

def changelog_section_blocks(section_body)
  block_lines = []
  blocks = []

  section_body.lines.each do |line|
    normalized_line = line.rstrip
    if normalized_line.match?(/^###+\s+/) && !block_lines.empty?
      blocks << normalize_changelog_block(block_lines)
      block_lines = [normalized_line]
    else
      block_lines << normalized_line
    end
  end

  blocks << normalize_changelog_block(block_lines) unless block_lines.empty?
  blocks.reject(&:empty?)
end

def normalize_changelog_block(lines)
  normalized_lines = lines.map(&:rstrip)
  normalized_lines.shift while normalized_lines.first == ""
  normalized_lines.pop while normalized_lines.last == ""
  normalized_lines.join("\n")
end

def normalize_heading_key(line)
  normalized = line.to_s.strip
  heading_level = normalized[/\A(#+)/, 1] || ""
  heading_text = normalized.sub(/\A#+\s+/, "")
                           .gsub(/\A(?:WARNING:)\s*/i, "")
                           .downcase
                           .gsub(/\s+/, " ")
  "#{heading_level} #{heading_text}".strip
end

def warning_changelog_heading?(line)
  line.to_s.match?(/\A###+\s+WARNING:/i)
end

def prefer_warning_heading(existing_block, incoming_heading)
  existing_heading = existing_block.lines.first&.rstrip || ""
  return existing_block if warning_changelog_heading?(existing_heading)
  return existing_block unless warning_changelog_heading?(incoming_heading)

  existing_block.sub(/\A[^\n]*/, incoming_heading)
end

def deduplicate_block_entries(block)
  lines = block.lines
  first_line = lines.first&.rstrip || ""
  return block unless first_line.match?(/\A###+\s+/)

  heading = first_line
  body_lines = lines.drop(1)
  entries = []
  current_entry = nil

  body_lines.each do |line|
    next if line.strip.empty? && entries.empty? && current_entry.nil?

    if line.start_with?("- ") || line.start_with?("* ")
      entries << current_entry if current_entry
      current_entry = +line
    elsif current_entry
      current_entry << line
    else
      entries << line
    end
  end
  entries << current_entry if current_entry

  seen_texts = {}
  unique_entries = entries.select do |entry|
    key = entry.to_s.strip
    if key.empty?
      true
    elsif seen_texts.key?(key)
      false
    else
      seen_texts[key] = true
      true
    end
  end

  "#{heading}\n#{unique_entries.join}"
end

def consolidate_changelog_blocks(blocks)
  consolidated = []
  heading_indices = {}

  blocks.each do |block|
    cleaned = block.strip
    next if cleaned.empty?

    first_line = cleaned.lines.first&.rstrip || ""
    heading_match = first_line.match(/\A(###+\s+.+)/)

    if heading_match
      heading_key = normalize_heading_key(heading_match[1])
      if heading_indices.key?(heading_key)
        idx = heading_indices[heading_key]
        consolidated[idx] = prefer_warning_heading(consolidated[idx], first_line)
        content_after_heading = cleaned.lines.drop(1).join.gsub(/\A\n+/, "").rstrip
        consolidated[idx] = "#{consolidated[idx].rstrip}\n#{content_after_heading}" unless content_after_heading.empty?
      else
        heading_indices[heading_key] = consolidated.length
        consolidated << cleaned
      end
    else
      consolidated << cleaned
    end
  end

  consolidated.map { |block| deduplicate_block_entries(block) }
end

def normalized_changelog_section_version(section)
  version = section[:version].to_s
  return nil if version.casecmp("Unreleased").zero?

  normalize_version_string(version)
end

def collapse_prerelease_sections(changelog, base_version, channel)
  parsed = parse_changelog_sections(changelog)
  sections = parsed[:sections]
  unreleased_section = sections.find { |section| section[:version] == "Unreleased" }
  return changelog unless unreleased_section

  target_regex = /\A#{Regexp.escape(base_version)}\.#{channel}\.\d+\z/i
  matching_sections = sections.select do |section|
    normalized_version = normalized_changelog_section_version(section)
    normalized_version&.match?(target_regex)
  end
  return changelog if matching_sections.empty?

  all_blocks = changelog_section_blocks(unreleased_section[:body]) +
               matching_sections.flat_map { |section| changelog_section_blocks(section[:body]) }
  consolidated = consolidate_changelog_blocks(all_blocks)
  merged_body = consolidated.join("\n\n").strip

  sections.reject! do |section|
    normalized_version = normalized_changelog_section_version(section)
    normalized_version&.match?(target_regex)
  end
  unreleased_section[:body] = merged_body.empty? ? "\n" : "\n\n#{merged_body}\n"

  render_changelog_sections(parsed[:prefix], sections)
end

def collapse_prerelease_series(changelog, base_version)
  %w[beta rc].reduce(changelog) do |current_changelog, channel|
    collapse_prerelease_sections(current_changelog, base_version, channel)
  end
end

def cleanup_collapsed_prerelease_links(changelog, base_version)
  compare_prefix = Regexp.escape("#{CHANGELOG_COMPARE_PREFIX}/")
  prerelease_pattern = /#{Regexp.escape(base_version)}\.(?:beta|rc)\.\d+/i
  stable_from = nil

  changelog.scan(/^\[#{prerelease_pattern}\]:\s*#{compare_prefix}(\S+)\.\.\./i) do |from_version,|
    stable_from = from_version unless from_version.delete_prefix("v").match?(prerelease_pattern)
  end

  if stable_from
    changelog = changelog.sub(
      /^(\[unreleased\]:\s*#{compare_prefix})\S+(\.\.\.#{CHANGELOG_BASE_BRANCH})/i,
      "\\1#{stable_from}\\2"
    )
  end

  changelog.gsub(/^\[#{prerelease_pattern}\]:.*\n/i, "")
end

def prepare_changelog_for_auto_version(changelog, gem_root)
  active_base_version = active_prerelease_base_version(gem_root, changelog)
  return changelog unless active_base_version

  changelog = collapse_prerelease_series(changelog, active_base_version)
  cleanup_collapsed_prerelease_links(changelog, active_base_version)
end

def next_active_prerelease_version(changelog, mode, gem_root)
  return nil unless %w[rc beta].include?(mode)

  active_base = active_prerelease_base_version(gem_root, changelog)
  return nil unless active_base

  indices = prerelease_indices_from_tags(gem_root, active_base, mode)
  next_index = indices.empty? ? 0 : indices.max + 1
  "#{active_base}.#{mode}.#{next_index}"
end

def compute_auto_version(changelog, mode, gem_root, changelog_for_bump: nil)
  changelog_for_bump ||= changelog

  if mode == "release"
    active_base_version = active_prerelease_base_version(gem_root, changelog)
    return active_base_version if active_base_version
  end

  active_version = next_active_prerelease_version(changelog, mode, gem_root)
  return active_version if active_version

  bump_type = inferred_bump_type_from_unreleased(changelog_for_bump)
  latest_stable = latest_stable_tag_version(gem_root)
  base_version = bump_stable_version(latest_stable, bump_type)

  return base_version if mode == "release"

  indices = prerelease_indices_from_tags(gem_root, base_version, mode)
  next_index = indices.empty? ? 0 : indices.max + 1
  "#{base_version}.#{mode}.#{next_index}"
end

def fetch_git_tag_date(gem_root, git_tag)
  output, status = Open3.capture2e("git", "-C", gem_root, "show", "-s", "--format=%cs", git_tag)
  return nil unless status.success?

  output.split("\n").last&.strip
end

def version_header_versions(changelog)
  changelog.scan(/^## \[([^\]]+)\]/).flatten
           .reject { |version| version.casecmp("Unreleased").zero? }
           .map { |version| normalize_version_string(version) }
end

def first_reference_link_version(changelog)
  match = changelog.match(/^\[(\d+\.\d+\.\d+(?:\.(?:beta|rc)\.\d+)?)\]:\s*#{Regexp.escape(CHANGELOG_COMPARE_PREFIX)}\/\S+\.\.\.v\1/m)
  match && normalize_version_string(match[1])
end

def ensure_previous_version_link!(changelog, previous_version)
  return unless previous_version
  return if changelog.match?(/^\[#{Regexp.escape(previous_version)}\]:/i)

  previous_previous_version = first_reference_link_version(changelog)
  return unless previous_previous_version

  link = "[#{previous_version}]: #{CHANGELOG_COMPARE_PREFIX}/v#{previous_previous_version}...v#{previous_version}\n"
  if changelog.include?("<!-- Version diff reference list -->")
    changelog.sub!("<!-- Version diff reference list -->\n", "<!-- Version diff reference list -->\n#{link}")
  else
    changelog << "\n<!-- Version diff reference list -->\n#{link}"
  end
end

def update_changelog_links(changelog, version, anchor)
  existing_unreleased = changelog.match(
    /^(?<prefix>\[unreleased\]:\s*#{Regexp.escape(CHANGELOG_COMPARE_PREFIX)}\/)(?<prev_version>\S+)(\.\.\.)(?<branch>#{CHANGELOG_BASE_BRANCH}|main)$/i
  )

  if existing_unreleased
    previous_version = existing_unreleased[:prev_version]
    replacement = "#{existing_unreleased[:prefix]}v#{version}...#{existing_unreleased[:branch]}\n" \
                  "#{anchor}: #{CHANGELOG_COMPARE_PREFIX}/#{previous_version}...v#{version}"
    changelog.sub!(existing_unreleased[0], replacement)
    return
  end

  previous_version = version_header_versions(changelog).find { |candidate| candidate != version }
  ensure_previous_version_link!(changelog, previous_version)

  unreleased_link = "[unreleased]: #{CHANGELOG_COMPARE_PREFIX}/v#{version}...#{CHANGELOG_BASE_BRANCH}\n"
  version_link = previous_version ? "#{anchor}: #{CHANGELOG_COMPARE_PREFIX}/v#{previous_version}...v#{version}\n" : ""
  insertion = "#{unreleased_link}#{version_link}"

  if changelog.include?("<!-- Version diff reference list -->")
    changelog.sub!("<!-- Version diff reference list -->\n", "<!-- Version diff reference list -->\n#{insertion}")
  else
    changelog << "\n<!-- Version diff reference list -->\n#{insertion}"
  end
end

def insert_version_header(changelog, anchor, tag_date)
  !!changelog.sub!("## [Unreleased]", "## [Unreleased]\n\n## #{anchor} - #{tag_date}")
end

desc "Updates CHANGELOG.md by inserting a version header and compare links.
Argument: Mode (`release`, `rc`, `beta`) or explicit git tag/version.

Modes:
  - release: auto-compute next stable version and collapse prior RC/beta sections
  - rc: auto-compute next RC version; prior prerelease sections are left in place
  - beta: auto-compute next beta version

No argument: use latest git tag.
For full entry analysis, run /update-changelog before this rake task."
task :update_changelog, %i[mode_or_tag] do |_, args|
  gem_root = gem_root_for_changelog
  changelog_path = File.join(gem_root, "CHANGELOG.md")
  changelog = File.read(changelog_path)
  input = args[:mode_or_tag].to_s.strip
  auto_mode = %w[release rc beta].find { |mode| mode == input.downcase }

  if auto_mode
    fetch_git_tags!(gem_root)
    prepared_changelog = auto_mode == "release" ? prepare_changelog_for_auto_version(changelog, gem_root) : changelog
    changelog_version = compute_auto_version(prepared_changelog, auto_mode, gem_root)
    changelog = prepared_changelog
    tag_date = Date.today.strftime("%Y-%m-%d")
    puts "Auto-computed #{auto_mode} version: #{changelog_version}"
  else
    git_tag = if input.empty?
                git_output, git_status = Open3.capture2e("git", "-C", gem_root, "describe", "--tags", "--abbrev=0")
                abort "Failed to get latest git tag.\n#{git_output}" unless git_status.success?

                git_output.strip
              else
                input
              end

    changelog_version = normalize_version_string(git_tag)
    tag_candidates = [git_tag, git_tag.start_with?("v") ? git_tag : "v#{git_tag}", "v#{changelog_version}"].uniq
    tag_date = tag_candidates.filter_map { |candidate| fetch_git_tag_date(gem_root, candidate) }.first ||
               Date.today.strftime("%Y-%m-%d")
  end

  anchor = "[#{changelog_version}]"
  header = "## #{anchor}"
  if changelog.include?(header)
    puts "Version #{changelog_version} is already documented in CHANGELOG.md"
    next
  end

  abort "Failed to insert version header: could not find '## [Unreleased]' in CHANGELOG.md" unless insert_version_header(changelog, anchor, tag_date)

  update_changelog_links(changelog, changelog_version, anchor)

  File.write(changelog_path, changelog)
  puts "Updated CHANGELOG.md with version header for #{changelog_version}"
  puts "NOTE: You still need to verify changelog entries before releasing."
end
