require 'cypress_on_rails/vcr/insert_eject_middleware'
require 'vcr'
require 'active_support/core_ext/hash' unless {}.respond_to?(:symbolize_keys)

module CypressOnRails
  module Vcr
    RSpec.describe InsertEjectMiddleware do
      let(:app) { ->(env) { [200, {}, ["app did #{env['PATH_INFO']}"]] } }
      let(:vcr) { class_double(VCR, turn_on!: true, turn_off!: true, insert_cassette: true, eject_cassette: true) }
      subject { described_class.new(app, vcr) }

      let(:env) { {} }

      let(:response) { subject.call(env) }

      def rack_input(json_value)
        StringIO.new(JSON.generate(json_value))
      end

      describe '/__e2e__/vcr/insert' do
        before do
          env['PATH_INFO'] = '/__e2e__/vcr/insert'
        end

        it do
          env['rack.input'] = rack_input(['cas1'])

          aggregate_failures do
            expect(response).to eq([201,
                                    { 'Content-Type' => 'application/json' },
                                    ['{"message":"OK"}']])
            expect(vcr).to have_received(:turn_on!)
            expect(vcr).to have_received(:insert_cassette).with('cas1', {})
          end
        end

        it 'works with record' do
          env['rack.input'] = rack_input(['cas1', { 'record' => 'new_episodes' }])

          aggregate_failures do
            expect(response).to eq([201,
                                    { 'Content-Type' => 'application/json' },
                                    ['{"message":"OK"}']])
            expect(vcr).to have_received(:insert_cassette).with('cas1', record: :new_episodes)
          end
        end

        it 'works with match_requests_on' do
          env['rack.input'] = rack_input(['cas1', { 'match_requests_on' => %w[method uri] }])

          aggregate_failures do
            expect(response).to eq([201,
                                    { 'Content-Type' => 'application/json' },
                                    ['{"message":"OK"}']])
            expect(vcr).to have_received(:insert_cassette).with('cas1', match_requests_on: %i[method uri])
          end
        end

        it 'works with serialize_with' do
          env['rack.input'] = rack_input(['cas1', { 'serialize_with' => 'yaml' }])

          aggregate_failures do
            expect(response).to eq([201,
                                    { 'Content-Type' => 'application/json' },
                                    ['{"message":"OK"}']])
            expect(vcr).to have_received(:insert_cassette).with('cas1', serialize_with: :yaml)
          end
        end

        it 'works with persist_with' do
          env['rack.input'] = rack_input(['cas1', { 'persist_with' => 'file_system' }])

          aggregate_failures do
            expect(response).to eq([201,
                                    { 'Content-Type' => 'application/json' },
                                    ['{"message":"OK"}']])
            expect(vcr).to have_received(:insert_cassette).with('cas1', persist_with: :file_system)
          end
        end
      end

      describe '/__e2e__/vcr/eject' do
        before do
          env['PATH_INFO'] = '/__e2e__/vcr/eject'
        end

        it do
          aggregate_failures do
            expect(response).to eq([201,
                                    { 'Content-Type' => 'application/json' },
                                    ['{"message":"OK"}']])
            expect(vcr).to have_received(:turn_off!)
            expect(vcr).to have_received(:eject_cassette)
          end
        end
      end

      describe '"Other paths"' do
        it 'calls vcr turn off the first time' do
          env['PATH_INFO'] = '/test'

          expect(response).to eq([200, {}, ['app did /test']])
          expect(vcr).to have_received(:turn_off!)
        end

        it 'runs app' do
          aggregate_failures do
            %w[/ /__e2e__/login command /e2e_command /].each do |path|
              env['PATH_INFO'] = path

              response = subject.call(env)

              expect(response).to eq([200, {}, ["app did #{path}"]])
              expect(vcr).to have_received(:turn_off!)
            end
          end
        end
      end
    end
  end
end
