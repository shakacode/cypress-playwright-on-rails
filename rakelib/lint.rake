# frozen_string_literal: true

desc 'Run RuboCop'
task :rubocop do
  sh 'bundle exec rubocop'
end

desc 'Run RuboCop with auto-correct'
task 'rubocop:auto_correct' do
  sh 'bundle exec rubocop -A'
end

desc 'Run all linters'
task lint: :rubocop

desc 'Auto-fix all linting issues'
task 'lint:fix' => 'rubocop:auto_correct'

desc 'Ensure all files end with newline'
task :check_newlines do
  files_without_newline = []

  # Define excluded directories
  excluded_dirs = %w[vendor/ node_modules/ .git/ pkg/ tmp/ coverage/]

  # Get all relevant files and filter out excluded directories more efficiently
  Dir.glob('**/*.{rb,rake,yml,yaml,md,gemspec,ru,erb,js,json}')
     .reject { |f| excluded_dirs.any? { |dir| f.start_with?(dir) } }
     .select { |f| File.file?(f) }
     .each do |file|
    content = File.read(file)
    files_without_newline << file unless content.empty? || content.end_with?("\n")
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

  # Define excluded directories (same as check_newlines)
  excluded_dirs = %w[vendor/ node_modules/ .git/ pkg/ tmp/ coverage/]

  # Get all relevant files and filter out excluded directories more efficiently
  Dir.glob('**/*.{rb,rake,yml,yaml,md,gemspec,ru,erb,js,json}')
     .reject { |f| excluded_dirs.any? { |dir| f.start_with?(dir) } }
     .select { |f| File.file?(f) }
     .each do |file|
    content = File.read(file)
    unless content.empty? || content.end_with?("\n")
      File.write(file, content + "\n")
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
