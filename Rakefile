require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/cypress_on_rails/*_spec.rb'
end

task default: %w[spec build]

# Remove bundler's default 'release' task to avoid confusion
Rake::Task['release'].clear if Rake::Task.task_defined?('release')

desc "Release gem (use release:prepare first to bump version)"
task :release do
  puts "⚠️  Direct 'rake release' is disabled."
  puts ""
  puts "To release a new version:"
  puts "  1. rake release:prepare[VERSION]  # Bump version and update CHANGELOG"
  puts "  2. git commit and push"
  puts "  3. rake release:publish           # Build and publish gem"
  puts ""
  puts "Example:"
  puts "  rake release:prepare[1.19.0]"
end

namespace :release do
  desc "Prepare release: bump version and update changelog"
  task :prepare, [:version] do |_t, args|
    require_relative 'lib/cypress_on_rails/version'

    version = args[:version]
    unless version
      puts "Usage: rake release:prepare[VERSION]"
      puts "Example: rake release:prepare[1.19.0]"
      exit 1
    end

    unless version.match?(/^\d+\.\d+\.\d+$/)
      puts "Error: Version must be in format X.Y.Z (e.g., 1.19.0)"
      exit 1
    end

    current_version = CypressOnRails::VERSION
    puts "Current version: #{current_version}"
    puts "New version: #{version}"

    # Confirm the version bump
    print "Continue? (y/n): "
    response = $stdin.gets.chomp.downcase
    unless response == 'y'
      puts "Aborted."
      exit 0
    end

    # Use gem bump to update version
    puts "\n→ Bumping version with gem-release..."
    unless system("gem bump --version #{version} --no-commit")
      puts "Error: Failed to bump version"
      exit 1
    end
    puts "✓ Updated version to #{version}"

    # Update CHANGELOG
    update_changelog(version, current_version)

    puts "\n✓ Version prepared!"
    puts "\nNext steps:"
    puts "  1. Review changes: git diff"
    puts "  2. Commit: git add -A && git commit -m 'Bump version to #{version}'"
    puts "  3. Push: git push origin master"
    puts "  4. Release: rake release:publish"
  end

  desc "Publish release: tag, build, and push gem"
  task :publish do
    require_relative 'lib/cypress_on_rails/version'
    version = CypressOnRails::VERSION

    # Pre-flight checks
    current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
    unless current_branch == 'master'
      puts "Error: Must be on master branch to release (currently on #{current_branch})"
      exit 1
    end

    if `git status --porcelain`.chomp != ''
      puts "Error: Working directory is not clean. Commit or stash changes first."
      exit 1
    end

    puts "Preparing to release version #{version}..."

    # Run tests
    puts "\n→ Running tests..."
    unless system('bundle exec rake spec')
      puts "Error: Tests failed. Fix them before releasing."
      exit 1
    end
    puts "✓ Tests passed"

    # Use gem release command
    puts "\n→ Releasing gem with gem-release..."
    unless system("gem release --tag --push")
      puts "Error: Failed to release gem"
      exit 1
    end

    puts "\n🎉 Successfully released version #{version}!"
    puts "\nNext steps:"
    puts "  1. Create GitHub release: https://github.com/shakacode/cypress-playwright-on-rails/releases/new?tag=v#{version}"
    puts "  2. Announce on Slack/Twitter"
    puts "  3. Close related issues"
  end
end

def update_changelog(version, current_version)
  changelog_file = 'CHANGELOG.md'
  changelog = File.read(changelog_file)

  today = Time.now.strftime('%Y-%m-%d')

  # Replace [Unreleased] with versioned entry
  if changelog.match?(/## \[Unreleased\]/)
    changelog.sub!(
      /## \[Unreleased\]/,
      "## [Unreleased]\n\n---\n\n## [#{version}] — #{today}\n[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v#{current_version}...v#{version}"
    )
    File.write(changelog_file, changelog)
    puts "✓ Updated #{changelog_file}"
  else
    puts "Warning: Could not find [Unreleased] section in CHANGELOG.md"
  end
end
