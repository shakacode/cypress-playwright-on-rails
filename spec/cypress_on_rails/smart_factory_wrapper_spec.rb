require 'cypress_on_rails/smart_factory_wrapper'
require 'factory_bot'

RSpec.describe CypressOnRails::SmartFactoryWrapper do
  FileSystemDummy = Struct.new(:file_hash) do
    def mtime(filename)
      file_hash.fetch(filename)
    end
  end

  subject do
    described_class.new(files: files,
                        factory: factory_double,
                        kernel: kernel_double,
                        file_system: file_double,
                        dir_system: dir_double)
  end

  let(:time_now) { Time.now }
  let(:mtime_hash) { { 'file1.rb' => time_now, 'file2.rb' => time_now } }
  let(:files) { %w[file1.rb file2.rb] }
  let(:factory_double) do
    class_double(FactoryBot, create: nil, create_list: nil, build: nil, build_list: nil, 'definition_file_paths=': nil, reload: nil)
  end
  let(:kernel_double) { class_double(Kernel, load: true) }
  let(:file_double) { FileSystemDummy.new(mtime_hash) }
  let(:dir_double) { class_double(Dir) }

  before do
    allow(Dir).to receive(:[]).with(*files) { mtime_hash.keys }
  end

  it 'loads all the files on first create it' do
    subject.create(:user)
    expect(kernel_double).to have_received(:load).with('file1.rb')
    expect(kernel_double).to have_received(:load).with('file2.rb')
  end

  it 'loads all the files on first create_list' do
    subject.create_list(:user, 10)
    expect(kernel_double).to have_received(:load).with('file1.rb')
    expect(kernel_double).to have_received(:load).with('file2.rb')
  end

  it 'sends delegates create to the factory' do
    subject.create(:user)
    expect(factory_double).to have_received(:create).with(:user, {})
  end

  it 'sends delegates create to the factory and symbolize keys' do
    subject.create(:user, { 'name' => 'name' })
    expect(factory_double).to have_received(:create).with(:user, { name: 'name' })
  end

  it 'sends delegates create to the factory and symbolize keys with trait' do
    subject.create(:user, 'trait1', { 'name' => 'name' })
    expect(factory_double).to have_received(:create).with(:user, :trait1, { name: 'name' })
  end

  it 'sends delegates create to the factory and symbolize keys with only trait' do
    subject.create(:user, 'trait2')
    expect(factory_double).to have_received(:create).with(:user, :trait2, {})
  end

  it 'sends delegates create_list to the factory' do
    subject.create_list(:note, 10)
    expect(factory_double).to have_received(:create_list).with(:note, 10)
  end

  it 'delegates build to the factory' do
    subject.build(:user)
    expect(factory_double).to have_received(:build).with(:user, {})
  end

  it 'delegates build to the factory and symbolize keys' do
    subject.build(:user, { 'name' => 'name' })
    expect(factory_double).to have_received(:build).with(:user, { name: 'name' })
  end

  it 'delegates build to the factory and symbolize keys with trait' do
    subject.build(:user, 'trait1', { 'name' => 'name' })
    expect(factory_double).to have_received(:build).with(:user, :trait1, { name: 'name' })
  end

  it 'delegates build to the factory and symbolize keys with only trait' do
    subject.build(:user, 'trait2')
    expect(factory_double).to have_received(:build).with(:user, :trait2, {})
  end

  it 'delegates build_list to the factory' do
    subject.build_list(:note, 10)
    expect(factory_double).to have_received(:build_list).with(:note, 10)
  end

  it 'wont load the files if they have not changed' do
    subject.create(:user)
    subject.create_list(:user, 2)
    expect(kernel_double).to have_received(:load).with('file1.rb').once
    expect(kernel_double).to have_received(:load).with('file2.rb').once
  end

  it 'reloads the files if any have changed' do
    subject.create(:user)
    expect(kernel_double).to have_received(:load).with('file1.rb').once
    expect(kernel_double).to have_received(:load).with('file2.rb').once

    mtime_hash['file1.rb'] = Time.now
    subject.create_list(:user, 2)
    expect(kernel_double).to have_received(:load).with('file1.rb').twice
    expect(kernel_double).to have_received(:load).with('file2.rb').twice
  end

  it 'reloads only the files that exist' do
    subject.always_reload = true
    subject.create(:user)
    expect(kernel_double).to have_received(:load).with('file1.rb').once
    expect(kernel_double).to have_received(:load).with('file2.rb').once

    mtime_hash.delete('file1.rb')
    subject.create_list(:user, 2)
    expect(kernel_double).to have_received(:load).with('file1.rb').once
    expect(kernel_double).to have_received(:load).with('file2.rb').twice
  end

  it 'resets factory if a file has changed' do
    subject.create(:user)
    expect(factory_double).to have_received(:reload)

    mtime_hash['file1.rb'] = Time.now
    subject.create_list(:user, 2)

    expect(factory_double).to have_received(:reload).twice
  end

  it 'alwayses reload the files enabled' do
    subject.always_reload = true
    subject.create_list(:user, 2)
    subject.create(:user)
    expect(kernel_double).to have_received(:load).with('file1.rb').twice
    expect(kernel_double).to have_received(:load).with('file2.rb').twice
  end

  it 'can manually reload' do
    subject.reload
    expect(factory_double).to have_received(:reload)
    expect(kernel_double).to have_received(:load).with('file1.rb')
    expect(kernel_double).to have_received(:load).with('file2.rb')
  end

  context 'files is a string' do
    let(:files) { 'file*.rb' }

    before do
      allow(Dir).to receive(:[]).with('file*.rb') { mtime_hash.keys }
    end

    it 'loads all the files on first create it' do
      subject.create(:user)
      expect(kernel_double).to have_received(:load).with('file1.rb')
      expect(kernel_double).to have_received(:load).with('file2.rb')
    end
  end
end
