# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

require File.expand_path('../../rakelib/newline_checker', __dir__)

RSpec.describe NewlineChecker do
  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.mkdir_p('spec')
        example.run
      end
    end
  end

  def write_file(path, content = "content\n")
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, content)
  end

  describe '.text_files' do
    it 'includes dotfiles, dot-directories, and common extensionless text files' do
      write_file('Gemfile')
      write_file('Rakefile')
      write_file('Gemfile.lock')
      write_file('Dockerfile')
      write_file('.rubocop.yml')
      write_file('.rubocop_todo.yml')
      write_file('.github/workflows/lint.yml')
      write_file('lib/example.rb')

      expect(described_class.text_files).to include(
        'Gemfile',
        'Rakefile',
        'Gemfile.lock',
        'Dockerfile',
        '.rubocop.yml',
        '.rubocop_todo.yml',
        '.github/workflows/lint.yml',
        'lib/example.rb'
      )
    end

    it 'excludes binary files even when their names match text globs' do
      write_file('config.yml', "\x00\x01binary")

      expect(described_class.text_files).not_to include('config.yml')
    end

    it 'excludes vendored, generated, and fixture trees' do
      write_file('specs_e2e/rails_6_1/config/app.yml')
      write_file('e2e/support/index.js')
      write_file('spec/fixtures/example.rb')

      expect(described_class.text_files).not_to include(
        'specs_e2e/rails_6_1/config/app.yml',
        'e2e/support/index.js',
        'spec/fixtures/example.rb'
      )
    end
  end

  describe '.missing_final_newline?' do
    it 'is true when the last byte is not a newline' do
      write_file('a.rb', 'puts 1')

      expect(described_class.missing_final_newline?('a.rb')).to be(true)
    end

    it 'is false when the file ends with a newline' do
      write_file('a.rb', "puts 1\n")

      expect(described_class.missing_final_newline?('a.rb')).to be(false)
    end

    it 'is false for an empty file' do
      write_file('a.rb', '')

      expect(described_class.missing_final_newline?('a.rb')).to be(false)
    end
  end

  # The generated pre-commit hook matches staged paths with this ERE, so it must
  # agree with the globs used by check_newlines / fix_newlines.
  describe '.staged_file_pattern' do
    subject(:pattern) { Regexp.new(described_class.staged_file_pattern) }

    it 'matches the same extensions and basenames as the globs' do
      expect(pattern).to match('lib/example.rb')
      expect(pattern).to match('Gemfile')
      expect(pattern).to match('sub/dir/Rakefile')
      expect(pattern).to match('Gemfile.lock')
    end

    it 'does not match unrelated paths' do
      expect(pattern).not_to match('image.png')
      expect(pattern).not_to match('MyGemfileHelper')
      expect(pattern).not_to match('lib/examplerb')
    end
  end
end
