# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'bin/install-hooks' do
  let(:source_script) { File.expand_path('../../bin/install-hooks', __dir__) }
  let(:repo_dir) { Dir.mktmpdir }
  let(:installer_path) { File.join(repo_dir, 'bin/install-hooks') }
  let(:hook_path) { File.join(repo_dir, '.git/hooks/pre-commit') }

  before do
    FileUtils.mkdir_p(File.join(repo_dir, 'bin'))
    FileUtils.cp(source_script, installer_path)
    raise 'git init failed' unless system('git', 'init', '-q', chdir: repo_dir)
  end

  after do
    FileUtils.remove_entry(repo_dir) if File.directory?(repo_dir)
  end

  def run_installer
    Open3.capture3(RbConfig.ruby, installer_path, chdir: repo_dir)
  end

  def run_hook
    Open3.capture3(hook_path, chdir: repo_dir)
  end

  def expect_success(status, output)
    expect(status.success?).to be(true), output
  end

  def git_add(path)
    raise "git add #{path} failed" unless system('git', 'add', path, chdir: repo_dir)
  end

  it 'backs up a pre-existing custom hook' do
    backup = "#{hook_path}.bak"
    custom_hook = "#!/bin/sh\necho custom\n"
    File.write(hook_path, custom_hook)

    stdout, stderr, status = run_installer

    expect_success(status, stdout + stderr)
    expect(File.read(backup)).to eq(custom_hook)
  end

  it 'does not back up a hook previously written by this installer' do
    stdout, stderr, status = run_installer
    expect_success(status, stdout + stderr)

    stdout, stderr, status = run_installer

    expect_success(status, stdout + stderr)
    expect(File.exist?("#{hook_path}.bak")).to be(false)
  end

  it 'allows staged binary files that fix_newlines cannot repair' do
    stdout, stderr, status = run_installer
    expect_success(status, stdout + stderr)
    File.binwrite(File.join(repo_dir, 'image.png'), "\x89PNG\x1A")
    git_add('image.png')

    stdout, stderr, status = run_hook

    expect_success(status, stdout + stderr)
  end

  it 'rejects staged extensionless text files missing a final newline' do
    stdout, stderr, status = run_installer
    expect_success(status, stdout + stderr)
    File.write(File.join(repo_dir, 'Gemfile'), 'source "https://rubygems.org"')
    git_add('Gemfile')

    stdout, stderr, status = run_hook

    expect(status.success?).to be(false)
    expect(stdout + stderr).to include('Gemfile')
  end
end
# rubocop:enable RSpec/DescribeClass
