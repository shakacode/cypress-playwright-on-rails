require 'cypress_on_rails/vcr/use_cassette_middleware'
require 'vcr'
require 'active_support/core_ext/hash' unless {}.respond_to?(:symbolize_keys)

module CypressOnRails
  module Vcr
    RSpec.describe UseCassetteMiddleware do
      let(:app) { ->(env) { [200, {}, ["app did #{env['PATH_INFO']}"]] } }
      let(:vcr) { VCR }
      subject { described_class.new(app, vcr) }

      let(:env) { { 'rack.input' => rack_input([]) } }

      let(:response) { subject.call(env) }

      def rack_input(json_value)
        StringIO.new(JSON.generate(json_value))
      end

      before do
        allow(vcr).to receive(:use_cassette).and_yield
      end

      it 'returns the application response using correct graphql cassette' do
        env['PATH_INFO'] = '/graphql'
        env['QUERY_STRING'] = 'operation=test'

        expect(response).to eq([200, {}, ['app did /graphql']])
        expect(vcr).to have_received(:use_cassette)
          .with('/graphql/test', hash_including(record: :new_episodes))
      end

      it 'returns the application response using default request path cassette' do
        allow(CypressOnRails).to receive(:configuration).and_return(double(vcr_use_cassette_mode: :once,
                                                                           logger: Logger.new(nil)))
        env['PATH_INFO'] = '/test/path'

        expect(response).to eq([200, {}, ['app did /test/path']])
        expect(vcr).to have_received(:use_cassette)
          .with('/test/path', hash_including(record: :once))
      end
    end
  end
end
