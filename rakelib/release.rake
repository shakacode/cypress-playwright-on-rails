# frozen_string_literal: true

require "bundler"
require_relative "task_helpers"

class RaisingMessageHandler
  def add_error(error)
    raise error
  end
end

# rubocop:disable Metrics/BlockLength

desc("Releases the gem using the given version.

IMPORTANT: the gem version must be in valid rubygem format (no dashes).

This task depends on the gem-release (ruby gem) which is installed via `bundle install`

1st argument: The new version in rubygem format (no dashes). Pass no argument to
              automatically perform a patch version bump.
2nd argument: Perform a dry run by passing 'true' as a second argument.

Note, accept defaults for rubygems options. Script will pause to get 2FA tokens.

Example: `rake release[2.1.0,false]`")
task :release, %i[gem_version dry_run] do |_t, args|
  include CypressOnRails::TaskHelpers

  # Check if there are uncommitted changes
  unless `git status --porcelain`.strip.empty?
    raise "You have uncommitted changes. Please commit or stash them before releasing."
  end

  args_hash = args.to_hash

  is_dry_run = args_hash[:dry_run] == 'true'

  gem_version = args_hash.fetch(:gem_version, "")

  # See https://github.com/svenfuchs/gem-release
  sh_in_dir(gem_root, "git pull --rebase")
  sh_in_dir(gem_root, "gem bump --no-commit #{gem_version.strip.empty? ? '' : %(-v #{gem_version})}")

  # Release the new gem version
  puts "Carefully add your OTP for Rubygems. If you get an error, run 'gem release' again."
  sh_in_dir(gem_root, "gem release") unless is_dry_run

  msg = <<~MSG
    Once you have successfully published, run these commands to update CHANGELOG.md:

    bundle exec rake update_changelog
    git commit -a -m 'Update CHANGELOG.md'
    git push
  MSG
  puts msg
end

# rubocop:enable Metrics/BlockLength
