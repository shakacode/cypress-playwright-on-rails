# frozen_string_literal: true

desc 'Run RuboCop'
task :rubocop do
  sh 'bundle exec rubocop'
end

desc 'Run RuboCop with autocorrect'
task 'rubocop:autocorrect' do
  sh 'bundle exec rubocop -A'
end

desc 'Run all linters'
task lint: :rubocop

desc 'Auto-fix all linting issues'
task 'lint:fix' => 'rubocop:autocorrect'

# Newline checking utilities
module NewlineChecker
  MAX_FILE_SIZE = 10 * 1024 * 1024
  EXCLUDED_DIRS = %w[vendor/ node_modules/ .git/ pkg/ tmp/ coverage/ specs_e2e/ e2e/ spec/fixtures/].freeze
  FILE_EXTENSIONS = '**/*.{rb,rake,yml,yaml,md,gemspec,ru,erb,js,json}'

  module_function

  def binary_file?(filepath)
    return false unless File.exist?(filepath)

    File.open(filepath, 'rb') do |file|
      chunk = file.read(8192) || ''
      return true if chunk.include?("\x00")
      return false if chunk.empty?

      non_printable = chunk.count("\x01-\x08\x0B\x0C\x0E-\x1F\x7F-\xFF")
      non_printable.to_f / chunk.size > 0.3
    end
  rescue StandardError
    true
  end

  def text_files
    Dir.glob(FILE_EXTENSIONS)
       .reject { |f| EXCLUDED_DIRS.any? { |dir| f.start_with?(dir) } }
       .select { |f| File.file?(f) && File.size(f) < MAX_FILE_SIZE && !binary_file?(f) }
  end
end

desc 'Ensure all files end with newline'
task :check_newlines do
  files_without_newline = []

  NewlineChecker.text_files.each do |file|
    File.open(file, 'rb') do |f|
      f.seek([f.size - 2, 0].max)
      tail = f.read
      files_without_newline << file unless tail.nil? || tail.empty? || tail.end_with?("\n")
    end
  end

  if files_without_newline.any?
    abort "Files missing final newline:\n#{files_without_newline.map { |f| "  #{f}" }.join("\n")}"
  else
    puts '✓ All files end with newline'
  end
end

desc 'Fix files missing final newline'
task :fix_newlines do
  fixed_files = []

  NewlineChecker.text_files.each do |file|
    needs_fix = File.open(file, 'rb') do |f|
      f.seek([f.size - 2, 0].max)
      tail = f.read
      !tail.nil? && !tail.empty? && !tail.end_with?("\n")
    end
    next unless needs_fix

    begin
      File.open(file, 'a') { |f| f.write("\n") }
      fixed_files << file
    rescue SystemCallError => e
      warn "Failed to fix #{file}: #{e.message}"
    end
  end

  if fixed_files.any?
    puts "Fixed #{fixed_files.length} files:"
    fixed_files.each { |f| puts "  #{f}" }
  else
    puts '✓ All files already end with newline'
  end
end
