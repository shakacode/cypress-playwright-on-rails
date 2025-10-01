# frozen_string_literal: true

desc("Releases the gem using the given version.

IMPORTANT: the gem version must be in valid rubygem format (no dashes).

This task depends on the gem-release ruby gem which is installed via `bundle install`

1st argument: The new version in rubygem format (no dashes). Pass no argument to
              automatically perform a patch version bump.
2nd argument: Perform a dry run by passing 'true' as a second argument.

Example: `rake release[1.19.0,false]`")
task :release, %i[gem_version dry_run] do |_t, args|
  def sh_in_dir(dir, command)
    puts "Running in #{dir}: #{command}"
    system("cd #{dir} && #{command}") || raise("Command failed: #{command}")
  end

  def gem_root
    File.expand_path('..', __dir__)
  end

  # Check if there are uncommitted changes
  unless `git status --porcelain`.strip.empty?
    raise "You have uncommitted changes. Please commit or stash them before releasing."
  end

  args_hash = args.to_hash
  is_dry_run = args_hash[:dry_run] == 'true'
  gem_version = args_hash.fetch(:gem_version, "")

  # See https://github.com/svenfuchs/gem-release
  sh_in_dir(gem_root, "git pull --rebase")
  sh_in_dir(gem_root, "gem bump --no-commit #{%(--version #{gem_version}) unless gem_version.strip.empty?}")

  # Release the new gem version
  puts "Carefully add your OTP for Rubygems. If you get an error, run 'gem release' again."
  sh_in_dir(gem_root, "gem release") unless is_dry_run

  msg = <<~MSG
    Once you have successfully published, update CHANGELOG.md:

    bundle exec rake update_changelog
    # Edit CHANGELOG.md to move unreleased changes to the new version section
    git commit -a -m 'Update CHANGELOG.md'
    git push
  MSG
  puts msg
end
