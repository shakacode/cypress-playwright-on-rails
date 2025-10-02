module CypressOnRails
  class InstallGenerator < Rails::Generators::Base
    class_option :api_prefix, type: :string, default: ''
    class_option :framework, type: :string, default: 'cypress'
    class_option :install_folder, type: :string, default: 'e2e'
    class_option :install_with, type: :string, default: 'yarn'
    class_option :experimental, type: :boolean, default: false
    source_root File.expand_path('templates', __dir__)

    def install_framework
      directories = options.install_folder.split('/')
      directories.pop
      install_dir = "#{Dir.pwd}/#{directories.join('/')}"

      command = nil
      packages = if options.framework == 'cypress'
                   %w[cypress cypress-on-rails]
                 elsif options.framework == 'playwright'
                   ['playwright', '@playwright/test']
                 end
      if options.install_with == 'yarn'
        command = "yarn --cwd=#{install_dir} add #{packages.join(' ')} --dev"
      elsif options.install_with == 'npm'
        command = "cd #{install_dir}; npm install #{packages.join(' ')} --save-dev"
      end
      if command
        say command
        raise "failed to install #{packages.join(' ')}" unless system(command)
      end

      if options.framework == 'cypress'
        template 'spec/cypress/support/index.js.erb', "#{options.install_folder}/cypress/support/index.js"
        copy_file 'spec/cypress/support/commands.js', "#{options.install_folder}/cypress/support/commands.js"
        copy_file 'spec/cypress.config.js', "#{options.install_folder}/cypress.config.js"
      end
      return unless options.framework == 'playwright'

      template 'spec/playwright/support/index.js.erb', "#{options.install_folder}/playwright/support/index.js"
      copy_file 'spec/playwright.config.js', "#{options.install_folder}/playwright.config.js"
    end

    def add_initial_files
      template 'config/initializers/cypress_on_rails.rb.erb', 'config/initializers/cypress_on_rails.rb'
      template 'spec/e2e/e2e_helper.rb.erb', "#{options.install_folder}/#{options.framework}/e2e_helper.rb"
      directory 'spec/e2e/app_commands', "#{options.install_folder}/#{options.framework}/app_commands"
      if options.framework == 'cypress'
        copy_file 'spec/cypress/support/on-rails.js', "#{options.install_folder}/cypress/support/on-rails.js"
        directory 'spec/cypress/e2e/rails_examples', "#{options.install_folder}/cypress/e2e/rails_examples"
      end
      return unless options.framework == 'playwright'

      copy_file 'spec/playwright/support/on-rails.js', "#{options.install_folder}/playwright/support/on-rails.js"
      directory 'spec/playwright/e2e/rails_examples', "#{options.install_folder}/playwright/e2e/rails_examples"
    end

    def update_files
      if options.framework == 'cypress'
        append_to_file "#{options.install_folder}/cypress/support/index.js",
                       "\nimport './on-rails'",
                       after: 'import \'./commands\''
      end
      return unless options.framework == 'playwright'

      append_to_file "#{options.install_folder}/playwright/support/index.js",
                     "\nimport './on-rails'",
                     after: '// Import commands.js using ES2015 syntax:'
    end
  end
end
