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

    # bin/install-hooks and .agents/bin/* are bare-named executables: they match
    # no extension and no known basename, so a name-only rule left this gem's
    # own scripts unchecked by the very task that enforces trailing newlines.
    it 'includes extensionless scripts identified by their shebang' do
      write_file('bin/install-hooks', "#!/usr/bin/env ruby\nputs 1\n")
      write_file('.agents/bin/validate', "#!/usr/bin/env bash\nexit 0\n")
      write_file('script/deploy', "#!/bin/sh\necho hi\n")

      expect(described_class.text_files).to include(
        'bin/install-hooks',
        '.agents/bin/validate',
        'script/deploy'
      )
    end

    it 'excludes extensionless files that are not scripts' do
      write_file('LICENSE', "MIT\n")
      write_file('bin/notes', "just prose\n")

      expect(described_class.text_files).not_to include('LICENSE', 'bin/notes')
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

    # Running specs_e2e/*/test.sh populates these two trees with tens of
    # thousands of files. They sit under the excluded specs_e2e/ prefix, so
    # traversal is pruned at specs_e2e/ and never descends into them.
    it 'excludes installed dependencies under an excluded tree' do
      write_file('specs_e2e/rails_6_1/test/node_modules/cypress/index.js')
      write_file('specs_e2e/rails_6_1/vendor/bundle/ruby/3.0.0/gems/rake/lib/rake.rb')

      expect(described_class.text_files).not_to include(
        'specs_e2e/rails_6_1/test/node_modules/cypress/index.js',
        'specs_e2e/rails_6_1/vendor/bundle/ruby/3.0.0/gems/rake/lib/rake.rb'
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

  # Guards against the regression that prompted this rule: the checker must see
  # the repository's own bare-named scripts, including ones this gem ships.
  describe 'coverage of this repository' do
    it 'covers the repository\'s extensionless scripts' do
      Dir.chdir(File.expand_path('../..', __dir__)) do
        covered = described_class.text_files

        expect(covered).to include(
          'bin/install-hooks',
          '.agents/bin/validate',
          '.agents/bin/lint'
        )
      end
    end
  end

  describe '.text_file?' do
    it 'accepts known extensions and basenames without opening the file' do
      expect(described_class.text_file?('lib/example.rb')).to be(true)
      expect(described_class.text_file?('Gemfile')).to be(true)
    end

    # File.extname('.gitignore') is "", but the hook's `case $base in *.*)` test
    # treats it as having an extension. Using "basename contains a dot" keeps
    # Ruby and bash in agreement.
    it 'treats dotfiles as extensioned, matching the shell test' do
      expect(described_class.extensionless?('.gitignore')).to be(false)
      expect(described_class.extensionless?('bin/install-hooks')).to be(true)
    end
  end

  # The same ERE drives both the tree walk in .text_files and the generated
  # pre-commit hook, so the rake tasks and the hook cannot disagree on scope.
  describe '.staged_file_pattern' do
    subject(:pattern) { Regexp.new(described_class.staged_file_pattern) }

    it 'matches every configured extension and extensionless basename' do
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
