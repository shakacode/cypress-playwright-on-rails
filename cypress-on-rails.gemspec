# -*- encoding: utf-8 -*-
$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require "cypress_on_rails/version"

Gem::Specification.new do |s|
  s.name        = "cypress-on-rails"
  s.version     = CypressOnRails::VERSION
  s.author      = ["miceportal team", 'Grant Petersen-Speelman']
  s.email       = ["info@miceportal.de", 'grantspeelman@gmail.com']
  s.homepage    = "http://github.com/shakacode/cypress-on-rails"
  s.summary     = "Integrates Cypress and Playwright with Rails or Rack applications"
  s.description = "Integrates Cypress and Playwright with Rails or Rack applications"
  s.post_install_message = 'The CypressDev constant is being deprecated and will be completely removed and replaced with CypressOnRails.'
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_dependency 'rack'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'railties', '>= 3.2'
  s.add_development_dependency 'factory_bot', '!= 6.4.5'
  s.add_development_dependency 'vcr'
  s.add_development_dependency 'gem-release'
  s.add_development_dependency 'rubocop', '~> 1.81'
  s.add_development_dependency 'rubocop-rake', '~> 0.7'
  s.add_development_dependency 'rubocop-rspec', '~> 3.7'

  s.required_ruby_version = '>= 3.0.0'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/shakacode/cypress-on-rails/issues",
    "changelog_uri"     => "https://github.com/shakacode/cypress-on-rails/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://github.com/shakacode/cypress-on-rails/blob/master/README.md",
    "homepage_uri"      => "http://github.com/shakacode/cypress-on-rails",
    "source_code_uri"   => "http://github.com/shakacode/cypress-on-rails"
}
end
