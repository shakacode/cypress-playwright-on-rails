require 'cypress_on_rails/simple_rails_factory'

RSpec.describe CypressOnRails::SimpleRailsFactory do
  subject { CypressOnRails::SimpleRailsFactory }

  class AppRecord
    def self.create!(*); end
  end

  before { allow(AppRecord).to receive(:create!) }

  it do
    subject.create('AppRecord', { my_args: 'Hello World' })

    expect(AppRecord).to have_received(:create!).with({ my_args: 'Hello World' })
  end

  it do
    subject.create('AppRecord', 'trait', { my_args: 'Hello World' })

    expect(AppRecord).to have_received(:create!).with('trait', { my_args: 'Hello World' })
  end

  it do
    subject.create('AppRecord')

    expect(AppRecord).to have_received(:create!).with({})
  end

  it do
    expect { subject.create('UnknownRecord', { my_args: 'Hello World' }) }
      .to raise_error(NameError)
  end
end
