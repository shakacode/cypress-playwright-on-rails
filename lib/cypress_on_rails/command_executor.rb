require 'cypress_on_rails/configuration'

module CypressOnRails
  # loads and evals the command files
  class CommandExecutor
    def self.perform(file, command_options = nil)
      load_e2e_helper
      file_data = File.read(file)
      eval file_data, binding, file
    rescue StandardError => e
      logger.error("fail to execute #{file}: #{e.message}")
      logger.error(e.backtrace.join("\n"))
      raise e
    end

    def self.load_e2e_helper
      e2e_helper_file = "#{configuration.install_folder}/e2e_helper.rb"
      cypress_helper_file = "#{configuration.install_folder}/cypress_helper.rb"
      if File.exist?(e2e_helper_file)
        Kernel.require e2e_helper_file
      elsif File.exist?(cypress_helper_file)
        Kernel.require cypress_helper_file
        warn 'cypress_helper.rb is deprecated, please rename the file to e2e_helper.rb'
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
