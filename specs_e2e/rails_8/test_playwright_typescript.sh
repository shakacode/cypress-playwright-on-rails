#!/usr/bin/env bash
# Generates the Playwright install with --typescript, type-checks the generated
# files with a strict tsconfig, and runs the generated example and the helper
# specs from specs_e2e/playwright_typescript against a real Rails server.
set -eo pipefail

echo '--- testing generated TypeScript playwright on rails 8'

export DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export RAILS_ENV=test
export BUNDLE_GEMFILE="$DIR/Gemfile"
FIXTURES="$DIR/../playwright_typescript"
INSTALL_FOLDER=e2e_ts
PID_FILE="$DIR/tmp/pids/playwright_typescript_server.pid"
cd "$DIR"

stop_server() {
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
  fi
}
trap stop_server EXIT

# start_server PORT [ENV=VALUE...]: boots Rails on 127.0.0.1:PORT and waits until it answers.
start_server() {
  local port=$1
  shift
  stop_server
  mkdir -p "$(dirname "$PID_FILE")"
  env "$@" PORT="$port" bundle exec ./bin/rails server -b 127.0.0.1 -p "$port" -e test -P "$PID_FILE" &
  for _ in $(seq 1 60); do
    if curl -sf -o /dev/null "http://127.0.0.1:$port/"; then return 0; fi
    sleep 1
  done
  echo "Rails did not answer on port $port" >&2
  return 1
}

echo '-- bundle install'
bundle config set --local path 'vendor/bundle'
bundle install --quiet --gemfile="$DIR/Gemfile" --retry 2

echo '-- migration'
bundle exec ./bin/rails db:drop || true
bundle exec ./bin/rails db:create db:migrate

echo '-- generate with --typescript'
rm -rf "$INSTALL_FOLDER"
bundle exec ./bin/rails g cypress_on_rails:install --install_folder="$INSTALL_FOLDER" --framework playwright --typescript --install_with=skip --force
cp -Rv "$FIXTURES"/. "$INSTALL_FOLDER"/

echo '-- install the pinned tools'
cd "$INSTALL_FOLDER"
npm install --no-audit --no-fund --no-package-lock

echo '-- strict type check of the generated config, helpers and example'
npx tsc -p tsconfig.json
npx playwright test --list

npx playwright install ${CI:+--with-deps} chromium

echo '-- run the example and the helper specs (BASE_URL and token set)'
TOKEN="token-$RANDOM-$RANDOM"
(cd "$DIR" && start_server 5017 CYPRESS_ON_RAILS_TOKEN="$TOKEN")
BASE_URL=http://127.0.0.1:5017 CYPRESS_ON_RAILS_TOKEN="$TOKEN" \
  npx playwright test --project=chromium rails_examples/using_scenarios.spec.ts helpers.spec.ts
stop_server

echo '-- run the same-server regression (BASE_URL unset, non-default port in the config)'
sed -i.bak 's#http://127.0.0.1:5017#http://127.0.0.1:4321#' playwright.config.ts
grep -q 'http://127.0.0.1:4321' playwright.config.ts
(cd "$DIR" && start_server 4321)
env -u BASE_URL -u CYPRESS_ON_RAILS_TOKEN npx playwright test --project=chromium same_server.spec.ts
