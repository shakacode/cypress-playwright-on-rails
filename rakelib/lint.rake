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

# Helper method to check if file is likely binary
def binary_file?(filepath)
  return false unless File.exist?(filepath)

  # Read first 8192 bytes to check for binary content
  File.open(filepath, 'rb') do |file|
    chunk = file.read(8192) || ''
    # File is binary if it contains null bytes or has high ratio of non-printable chars
    return true if chunk.include?("\x00")

    # Check for high ratio of non-printable characters
    non_printable = chunk.count("\x01-\x08\x0B\x0C\x0E-\x1F\x7F-\xFF")
    non_printable.to_f / chunk.size > 0.3
  end
rescue StandardError
  # If we can't read the file, assume it's not something we should check
  true
end

# Maximum file size to check (10MB)
MAX_FILE_SIZE = 10 * 1024 * 1024

desc 'Ensure all files end with newline'
task :check_newlines do
  files_without_newline = []

  # Define excluded directories (matching RuboCop config)
  excluded_dirs = %w[vendor/ node_modules/ .git/ pkg/ tmp/ coverage/ specs_e2e/ e2e/ spec/fixtures/]

  # Get all relevant files and filter out excluded directories more efficiently
  Dir.glob('**/*.{rb,rake,yml,yaml,md,gemspec,ru,erb,js,json}')
     .reject { |f| excluded_dirs.any? { |dir| f.start_with?(dir) } }
     .select { |f| File.file?(f) && File.size(f) < MAX_FILE_SIZE && !binary_file?(f) }
     .each do |file|
    # Read only the last few bytes to check for newline
    File.open(file, 'rb') do |f|
      f.seek([f.size - 2, 0].max)
      tail = f.read
      files_without_newline << file unless tail.nil? || tail.empty? || tail.end_with?("\n")
    end
  end

  if files_without_newline.any?
    puts 'Files missing final newline:'
    files_without_newline.each { |f| puts "  #{f}" }
    exit 1
  else
    puts '✓ All files end with newline'
  end
end

desc 'Fix files missing final newline'
task :fix_newlines do
  fixed_files = []

  # Define excluded directories (matching RuboCop config)
  excluded_dirs = %w[vendor/ node_modules/ .git/ pkg/ tmp/ coverage/ specs_e2e/ e2e/ spec/fixtures/]

  # Get all relevant files and filter out excluded directories more efficiently
  Dir.glob('**/*.{rb,rake,yml,yaml,md,gemspec,ru,erb,js,json}')
     .reject { |f| excluded_dirs.any? { |dir| f.start_with?(dir) } }
     .select { |f| File.file?(f) && File.size(f) < MAX_FILE_SIZE && !binary_file?(f) }
     .each do |file|
    # Read file to check if it needs a newline
    content = File.read(file)
    unless content.empty? || content.end_with?("\n")
      File.write(file, "#{content}\n")
      fixed_files << file
    end
  end

  if fixed_files.any?
    puts "Fixed #{fixed_files.length} files:"
    fixed_files.each { |f| puts "  #{f}" }
  else
    puts '✓ All files already end with newline'
  end
end
