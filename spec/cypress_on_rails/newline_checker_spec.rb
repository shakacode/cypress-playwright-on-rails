# frozen_string_literal: true

require 'fileutils'
require 'rake'
require 'tmpdir'

load File.expand_path('../../rakelib/lint.rake', __dir__) unless defined?(NewlineChecker)

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
end
