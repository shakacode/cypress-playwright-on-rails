# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'bin/install-hooks' do
  let(:project_root) { File.expand_path('../..', __dir__) }
  let(:repo_dir) { Dir.mktmpdir }
  let(:installer_path) { File.join(repo_dir, 'bin/install-hooks') }
  let(:hook_path) { File.join(repo_dir, '.git/hooks/pre-commit') }

  before do
    FileUtils.mkdir_p(File.join(repo_dir, 'bin'))
    FileUtils.mkdir_p(File.join(repo_dir, 'rakelib'))
    FileUtils.cp(File.join(project_root, 'bin/install-hooks'), installer_path)
    # The installer derives the hook's scope from this shared module.
    FileUtils.cp(File.join(project_root, 'rakelib/newline_checker.rb'), File.join(repo_dir, 'rakelib'))
    raise 'git init failed' unless system('git', 'init', '-q', chdir: repo_dir)
  end

  after do
    FileUtils.remove_entry(repo_dir) if File.directory?(repo_dir)
  end

  def run_installer
    Open3.capture3(RbConfig.ruby, installer_path, chdir: repo_dir)
  end

  def run_hook(env = {})
    Open3.capture3(env, hook_path, chdir: repo_dir)
  end

  def install_hook!
    stdout, stderr, status = run_installer
    expect_success(status, stdout + stderr)
  end

  def expect_success(status, output)
    expect(status.success?).to be(true), output
  end

  def git_add(path)
    raise "git add #{path} failed" unless system('git', 'add', path, chdir: repo_dir)
  end

  def write_repo_file(relative_path, contents)
    full_path = File.join(repo_dir, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.binwrite(full_path, contents)
    full_path
  end

  # Absolute path of the real grep, so the stub below can delegate to it.
  def real_grep_path
    ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).each do |dir|
      candidate = File.join(dir, 'grep')
      return candidate if File.executable?(candidate) && !File.directory?(candidate)
    end
    nil
  end

  # Creates a `grep` earlier on PATH that rejects any flag containing `z`,
  # mimicking a grep without the GNU-only `-z` extension.
  def stub_grep_without_z!(real_grep)
    stub_dir = File.join(repo_dir, 'stub-bin')
    FileUtils.mkdir_p(stub_dir)
    stub = File.join(stub_dir, 'grep')
    File.write(stub, <<~SH)
      #!/bin/sh
      for arg in "$@"; do
        case "$arg" in
          -*z*) echo "grep: illegal option -- z" >&2; exit 2 ;;
        esac
      done
      exec #{real_grep} "$@"
    SH
    FileUtils.chmod(0o755, stub)
    stub_dir
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
    install_hook!

    stdout, stderr, status = run_installer

    expect_success(status, stdout + stderr)
    expect(File.exist?("#{hook_path}.bak")).to be(false)
  end

  it 'allows staged binary files that fix_newlines cannot repair' do
    install_hook!
    write_repo_file('image.png', "\x89PNG\x1A")
    git_add('image.png')

    stdout, stderr, status = run_hook

    expect_success(status, stdout + stderr)
  end

  it 'rejects staged extensionless text files missing a final newline' do
    install_hook!
    write_repo_file('Gemfile', 'source "https://rubygems.org"')
    git_add('Gemfile')

    stdout, stderr, status = run_hook

    expect(status.success?).to be(false)
    expect(stdout + stderr).to include('Gemfile')
  end

  # NewlineChecker::EXCLUDED_DIRS skips these trees, so `rake fix_newlines`
  # cannot repair them. The hook must not reject what the fix command ignores.
  it 'ignores staged paths excluded from the newline rake tasks' do
    install_hook!
    write_repo_file('specs_e2e/rails_6_1/config/no_newline.yml', 'key: value')
    git_add('specs_e2e/rails_6_1/config/no_newline.yml')

    stdout, stderr, status = run_hook

    expect_success(status, stdout + stderr)
  end

  # Regression guard: the hook used `grep -z`, a GNU extension. A grep that
  # rejects the flag exits non-zero with no output, which silently disabled the
  # entire newline check instead of failing loudly.
  it 'still detects missing newlines when grep rejects the GNU-only -z flag' do
    grep = real_grep_path
    skip 'no grep on PATH' if grep.nil?

    stub_dir = stub_grep_without_z!(grep)
    install_hook!
    write_repo_file('Gemfile', 'source "https://rubygems.org"')
    git_add('Gemfile')

    stdout, stderr, status = run_hook('PATH' => "#{stub_dir}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH', '')}")

    expect(status.success?).to be(false)
    expect(stdout + stderr).to include('Missing final newline')
    expect(stdout + stderr).not_to include('illegal option')
  end
end
# rubocop:enable RSpec/DescribeClass
