# frozen_string_literal: true

require 'find'

# Single source of truth for "which files must end with a final newline".
#
# Both `rake check_newlines` / `rake fix_newlines` (see rakelib/lint.rake) and
# the generated git pre-commit hook (see bin/install-hooks) derive their scope
# from the constants below, so the two mechanisms cannot drift apart. If the
# hook rejected a file the rake tasks could not repair, `bundle exec rake
# fix_newlines` would be dead-end advice.
module NewlineChecker
  MAX_FILE_SIZE = 10 * 1024 * 1024

  # Directory prefixes (relative to the repository root) that are skipped.
  # These hold vendored, generated, or fixture trees this gem does not own.
  EXCLUDED_DIRS = %w[
    vendor/
    node_modules/
    .git/
    pkg/
    tmp/
    coverage/
    specs_e2e/
    e2e/
    spec/fixtures/
  ].freeze

  # Text file extensions that are checked.
  EXTENSIONS = %w[rb rake yml yaml md gemspec ru erb js json].freeze

  # Extension-less files that are checked. RuboCop's Layout/TrailingEmptyLines
  # already inspects `Gemfile` and `Rakefile`, so omitting them here would make
  # the two enforcement mechanisms disagree.
  EXTENSIONLESS_FILENAMES = %w[
    Gemfile
    Gemfile.lock
    Rakefile
    Dockerfile
    Procfile
    Guardfile
    Capfile
  ].freeze

  # One POSIX ERE describing every checked path, derived from the two lists
  # above. It is both the matcher used when walking the tree and the pattern
  # interpolated into the generated pre-commit hook, so the rake tasks and the
  # hook cannot disagree about which files are in scope.
  TEXT_FILE_PATTERN = [
    "(^|/)(#{EXTENSIONLESS_FILENAMES.map { |name| Regexp.escape(name) }.join('|')})$",
    "\\.(#{EXTENSIONS.join('|')})$"
  ].join('|').freeze
  TEXT_FILE_MATCHER = Regexp.new(TEXT_FILE_PATTERN)

  module_function

  # Interpolated into the generated pre-commit hook by bin/install-hooks.
  def staged_file_pattern
    TEXT_FILE_PATTERN
  end

  # Space-separated excluded prefixes for the generated pre-commit hook.
  # None of EXCLUDED_DIRS contain whitespace, so this round-trips safely.
  def staged_excluded_prefixes
    EXCLUDED_DIRS.join(' ')
  end

  def excluded?(filepath)
    EXCLUDED_DIRS.any? { |dir| filepath.start_with?(dir) }
  end

  def binary_file?(filepath)
    return false unless File.exist?(filepath)

    File.open(filepath, 'rb') do |file|
      chunk = file.read(8192) || ''
      return true if chunk.include?("\x00")
      return false if chunk.empty?

      bytes = chunk.b.bytes
      non_printable = bytes.count { |byte| (byte < 32 && ![9, 10, 13].include?(byte)) || byte == 127 }
      non_printable.to_f / bytes.size > 0.3
    end
  rescue StandardError
    true
  end

  # Walks the working tree, pruning EXCLUDED_DIRS during traversal rather than
  # filtering them out afterwards.
  #
  # Dir.glob cannot express an exclusion, so the previous implementation
  # descended into every directory and discarded the results. In a checkout
  # where specs_e2e/*/test.sh has been run -- which populates
  # specs_e2e/*/vendor/bundle and specs_e2e/*/test/node_modules -- that meant
  # collecting tens of thousands of paths to keep about a hundred.
  def text_files
    files = []

    Find.find('.') do |path|
      relative = path.delete_prefix('./')

      if File.directory?(path)
        Find.prune if excluded?("#{relative}/")
        next
      end

      next unless TEXT_FILE_MATCHER.match?(relative)
      next unless File.file?(path) && File.size(path) < MAX_FILE_SIZE && !binary_file?(path)

      files << relative
    end

    files
  end

  # True when the file has content and its last byte is not a newline.
  def missing_final_newline?(filepath)
    byte_count = File.size(filepath)
    return false if byte_count.zero?

    File.open(filepath, 'rb') do |file|
      file.seek(-1, IO::SEEK_END)
      file.read(1) != "\n"
    end
  end
end
