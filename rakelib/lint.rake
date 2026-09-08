# frozen_string_literal: true

require_relative 'newline_checker'

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

desc 'Ensure all files end with newline'
task :check_newlines do
  files_without_newline = NewlineChecker.text_files.select { |file| NewlineChecker.missing_final_newline?(file) }

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
    next unless NewlineChecker.missing_final_newline?(file)

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
