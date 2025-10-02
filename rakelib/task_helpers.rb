# frozen_string_literal: true

module CypressOnRails
  module TaskHelpers
    # Returns the root folder of the cypress-on-rails gem
    def gem_root
      File.expand_path("..", __dir__)
    end

    # Executes a string or an array of strings in a shell in the given directory
    def sh_in_dir(dir, *shell_commands)
      Dir.chdir(dir) do
        # Without `with_unbundled_env`, running bundle in the child directories won't correctly
        # update the Gemfile.lock
        Bundler.with_unbundled_env do
          shell_commands.flatten.each do |shell_command|
            sh(shell_command.strip)
          end
        end
      end
    end
  end
end