# frozen_string_literal: true

module CypressOnRails
  module TaskHelpers
    # Returns the root folder of the cypress-on-rails gem
    def gem_root
      File.expand_path("..", __dir__)
    end

    # Executes a string or an array of strings in a shell in the given directory
    def sh_in_dir(dir, *shell_commands)
      shell_commands.flatten.each { |shell_command| sh %(cd #{dir} && #{shell_command.strip}) }
    end
  end
end
