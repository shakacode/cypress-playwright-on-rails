#!/usr/bin/env bash
set -eo pipefail

echo '--- testing rails 6.1.7'

echo '-- setting environment'
export DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export RAILS_ENV=test
export BUNDLE_GEMFILE="$DIR/Gemfile"
cd $DIR

echo '-- bundle install'
bundle --version
bundle config set --local path 'vendor/bundle'
bundle install --quiet --gemfile="$DIR/Gemfile" --retry 2

echo '-- migration'
bundle exec ./bin/rails db:drop || true
bundle exec ./bin/rails db:create db:migrate

echo '-- cypress install'
bundle exec ./bin/rails g cypress_on_rails:install --install_folder=test --framework cypress --install_with=npm --force
rm -vf test/cypress/e2e/rails_examples/using_vcr.cy.js

echo '-- start rails server'
# make sure the server is not running
(kill -9 `cat ../server.pid` || true )

bundle exec ./bin/rails server -p 5017 -e test -P ../server.pid &
sleep 2 # give rails a chance to start up correctly

echo '-- cypress run'
cp -fv ../cypress.config.js test/
cd test
npx cypress install
# if [ -z $CYPRESS_RECORD_KEY ]
# then
#     npx cypress run
# else
    npx cypress run # --record
# fi

echo '-- playwright install'
cd ..
bundle exec ./bin/rails g cypress_on_rails:install --install_folder=test --framework playwright --install_with=npm --force
rm -vf test/playwright/e2e/rails_examples/using_vcr.cy.js

echo '-- playwright run'
cd test
cp -fv ../../playwright.config.js .
npx playwright install-deps
npx playwright install
npx playwright test test/playwright
# npx playwright show-report

echo '-- stop rails server'
kill -9 `cat ../../server.pid` || true
