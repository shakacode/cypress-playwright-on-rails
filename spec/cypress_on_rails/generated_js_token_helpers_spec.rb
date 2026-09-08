# The JS helpers ship as generator templates and this repo has no JavaScript test
# harness, so the token wiring is guarded here at the source level.
#
# The main thing being pinned is the `ON_RAILS_TOKEN` fallback. It reads like dead
# naming, but cypress strips the CYPRESS_ prefix from OS environment variables, so
# the plain `export CYPRESS_ON_RAILS_TOKEN=...` that the README recommends for
# sharing one value with the rails server only reaches the helpers under that key.
RSpec.describe 'generated JS token helpers' do
  def helper_source(relative_path)
    File.read(File.join(File.expand_path('../..', __dir__), relative_path))
  end

  %w[
    lib/generators/cypress_on_rails/templates/spec/cypress/support/on-rails.js
    plugin/support/index.js
  ].each do |path|
    describe path do
      let(:source) { helper_source(path) }

      it 'reads the token set in cypress.env.json' do
        expect(source).to include("Cypress.env('CYPRESS_ON_RAILS_TOKEN')")
      end

      it 'falls back to the prefix-stripped shell spelling' do
        expect(source).to include("Cypress.env('ON_RAILS_TOKEN')")
      end

      it 'documents the fallback in the comment block' do
        comments = source.lines.select { |line| line.strip.start_with?('//') }.join

        expect(comments).to include("Cypress.env('ON_RAILS_TOKEN')")
      end

      it 'sends the token as the X-Cypress-On-Rails-Token header' do
        expect(source).to include("'X-Cypress-On-Rails-Token'")
      end
    end
  end

  describe 'lib/generators/cypress_on_rails/templates/spec/playwright/support/on-rails.js' do
    let(:source) do
      helper_source('lib/generators/cypress_on_rails/templates/spec/playwright/support/on-rails.js')
    end

    it 'reads the token from the environment' do
      expect(source).to include('process.env.CYPRESS_ON_RAILS_TOKEN')
    end

    it 'does not carry the cypress only fallback' do
      # playwright does no prefix stripping, so ON_RAILS_TOKEN there would be a new
      # undocumented name rather than a compatibility fallback
      expect(source).to_not include('process.env.ON_RAILS_TOKEN')
    end

    it 'sends the token as the X-Cypress-On-Rails-Token header' do
      expect(source).to include("'X-Cypress-On-Rails-Token'")
    end
  end
end
