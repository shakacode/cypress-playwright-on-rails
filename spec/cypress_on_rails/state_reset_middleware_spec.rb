require 'cypress_on_rails/state_reset_middleware'

RSpec.describe CypressOnRails::StateResetMiddleware do
  let(:app) { ->(env) { [200, {}, ["app did #{env['PATH_INFO']}"]] } }
  subject { described_class.new(app) }

  let(:env) { {} }

  let(:response) { subject.call(env) }

  before do
    # the reset itself talks to the database and Rails.cache, both out of scope here
    allow(subject).to receive(:reset_application_state)
  end

  %w[/__cypress__/reset_state /cypress_rails_reset_state].each do |path|
    describe path do
      before do
        env['PATH_INFO'] = path
      end

      it 'resets the state' do
        aggregate_failures do
          expect(response).to eq([200, { 'Content-Type' => 'text/plain' }, ['State reset completed']])
          expect(subject).to have_received(:reset_application_state)
        end
      end

      context 'with a middleware_token configured' do
        let(:token) { 'super-secret-token' }
        let(:forbidden) do
          [403, { 'Content-Type' => 'application/json' }, ['{"message":"invalid or missing token"}']]
        end

        before do
          CypressOnRails.configure { |config| config.middleware_token = token }
        end

        it 'rejects a request without the token header' do
          aggregate_failures do
            expect(response).to eq(forbidden)
            expect(subject).to_not have_received(:reset_application_state)
          end
        end

        it 'rejects a request with the wrong token' do
          env['HTTP_X_CYPRESS_ON_RAILS_TOKEN'] = 'not-the-token'

          aggregate_failures do
            expect(response).to eq(forbidden)
            expect(subject).to_not have_received(:reset_application_state)
          end
        end

        it 'resets the state when the token matches' do
          env['HTTP_X_CYPRESS_ON_RAILS_TOKEN'] = token

          aggregate_failures do
            expect(response).to eq([200, { 'Content-Type' => 'text/plain' }, ['State reset completed']])
            expect(subject).to have_received(:reset_application_state)
          end
        end
      end
    end
  end

  describe 'other paths' do
    it 'runs the app' do
      env['PATH_INFO'] = '/test'

      aggregate_failures do
        expect(response).to eq([200, {}, ['app did /test']])
        expect(subject).to_not have_received(:reset_application_state)
      end
    end

    it 'runs the app even when a middleware_token is configured' do
      CypressOnRails.configure { |config| config.middleware_token = 'super-secret-token' }
      env['PATH_INFO'] = '/test'

      expect(response).to eq([200, {}, ['app did /test']])
    end
  end
end
