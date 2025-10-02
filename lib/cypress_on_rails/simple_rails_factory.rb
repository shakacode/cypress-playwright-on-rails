module CypressOnRails
  module SimpleRailsFactory
    def self.create(type, *params)
      params = [{}] if params.empty?
      type.camelize.constantize.create!(*params)
    end

    def self.create_list(type, amount, *params)
      amount.to_i.times do
        create(type, *params)
      end
    end

    # to be API compatible with factorybot
    def self.definition_file_paths=(*); end
    def self.reload; end
  end
end
