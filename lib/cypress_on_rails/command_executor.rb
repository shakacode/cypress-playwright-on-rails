require 'cypress_on_rails/configuration'

module CypressOnRails
  # loads and evals the command files
  class CommandExecutor
    def self.perform(file,command_options = nil)
      load_e2e_helper
      file_data = File.read(file)
      eval file_data, binding, file
    rescue => e
      logger.error("fail to execute #{file}: #{e.message}")
      logger.error(e.backtrace.join("\n"))
      raise e
    end

    def self.load_e2e_helper
      e2e_helper_file = "#{configuration.install_folder}/e2e_helper.rb"
      cypress_helper_file = "#{configuration.install_folder}/cypress_helper.rb"

      # Check for old structure (files in framework subdirectory)
      old_cypress_location = "#{configuration.install_folder}/cypress/e2e_helper.rb"
      old_playwright_location = "#{configuration.install_folder}/playwright/e2e_helper.rb"

      # Try to load from the correct location first
      if File.exist?(e2e_helper_file)
        Kernel.require e2e_helper_file
      elsif File.exist?(cypress_helper_file)
        Kernel.require cypress_helper_file
        warn "cypress_helper.rb is deprecated, please rename the file to e2e_helper.rb"
      # Fallback: load from old location if new location doesn't exist
      elsif File.exist?(old_cypress_location) || File.exist?(old_playwright_location)
        old_location = File.exist?(old_cypress_location) ? old_cypress_location : old_playwright_location
        logger.warn "=" * 80
        logger.warn "DEPRECATION WARNING: Old folder structure detected!"
        logger.warn "Found e2e_helper.rb at: #{old_location}"
        logger.warn "This file should be at: #{e2e_helper_file}"
        logger.warn ""
        logger.warn "Loading from old location for now, but this will stop working in a future version."
        logger.warn "The generator now creates e2e_helper.rb and app_commands/ at the install_folder"
        logger.warn "root, not inside the framework subdirectory."
        logger.warn ""
        logger.warn "To fix this, run: mv #{old_location} #{e2e_helper_file}"
        logger.warn "Also move app_commands: mv #{File.dirname(old_location)}/app_commands #{configuration.install_folder}/"
        logger.warn "See CHANGELOG.md for full migration guide."
        logger.warn "=" * 80
        # Load from old location as fallback
        Kernel.require old_location
      else
        logger.warn "could not find #{e2e_helper_file} nor #{cypress_helper_file}"
      end
    end

    def self.logger
      configuration.logger
    end

    def self.configuration
      CypressOnRails.configuration
    end
  end
end
