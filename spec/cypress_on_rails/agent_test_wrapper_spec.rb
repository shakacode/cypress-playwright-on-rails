# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'

# rubocop:disable-next RSpec/DescribeClass
RSpec.describe '.agents/bin/test' do
  let(:source_root) { File.expand_path('../..', __dir__) }
  let(:source_script) { File.join(source_root, '.agents/bin/test') }

  def with_repo
    Dir.mktmpdir do |root|
      script = File.join(root, '.agents/bin/test')
      spec_dir = File.join(root, 'spec')
      stub_dir = File.join(root, 'stub')
      args_file = File.join(root, 'bundle-args')
      FileUtils.mkdir_p([File.dirname(script), spec_dir, stub_dir])
      FileUtils.cp(source_script, script)
      FileUtils.chmod(0o755, script)
      File.write(File.join(spec_dir, 'one_spec.rb'), "RSpec.describe('one') {}\n")
      File.write(File.join(spec_dir, 'two_spec.rb'), "RSpec.describe('two') {}\n")
      File.write(File.join(root, 'outside_spec.rb'), "RSpec.describe('outside') {}\n")
      File.symlink(File.join(root, 'outside_spec.rb'), File.join(spec_dir, 'linked_spec.rb'))
      bundle = File.join(stub_dir, 'bundle')
      File.write(bundle, "#!/bin/sh\nprintf '%s\\0' \"$@\" > \"$BUNDLE_ARGS_FILE\"\n")
      FileUtils.chmod(0o755, bundle)
      env = {
        'BASH_ENV' => nil,
        'BUNDLE_ARGS_FILE' => args_file,
        'PATH' => [stub_dir, ENV.fetch('PATH')].join(File::PATH_SEPARATOR)
      }
      yield root, env, args_file
    end
  end

  def run_test_script(root, env, *arguments)
    Open3.capture3(env, 'bash', File.join(root, '.agents/bin/test'), *arguments, chdir: root)
  end

  def bundle_arguments(path)
    File.binread(path).split("\0")
  end

  it 'runs the default Rake suite when no focused paths are supplied' do
    with_repo do |root, env, args_file|
      _stdout, stderr, status = run_test_script(root, env)

      expect(status).to be_success, stderr
      expect(bundle_arguments(args_file)).to eq(%w[exec rake])
    end
  end

  it 'forwards valid paths and line filters to RSpec' do
    with_repo do |root, env, args_file|
      _stdout, stderr, status = run_test_script(root, env, 'spec/one_spec.rb:12', 'spec/two_spec.rb')

      expect(status).to be_success, stderr
      expect(bundle_arguments(args_file)).to eq(%w[exec rspec spec/one_spec.rb:12 spec/two_spec.rb])
    end
  end

  it 'rejects traversal, symlink escapes, missing paths, and mixed unsafe arguments before running RSpec' do
    with_repo do |root, env, args_file|
      [
        ['spec/../outside_spec.rb'],
        ['spec/linked_spec.rb'],
        ['spec/missing_spec.rb'],
        ['spec/one_spec.rb', 'spec/../outside_spec.rb']
      ].each do |arguments|
        _stdout, _stderr, status = run_test_script(root, env, *arguments)

        expect(status).not_to be_success
      end

      expect(File.exist?(args_file)).to be(false)
    end
  end
end
