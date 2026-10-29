#!/usr/bin/env bash
# Runs transactional_server_smoke_test.rb in a sample app, on SQLite and, when
# E2E_POSTGRESQL=1, on PostgreSQL too. Called by rails_7_2/test.sh and
# rails_8/test.sh after `bundle install`; runs on its own as well:
#
#   specs_e2e/transactional_server_smoke.sh specs_e2e/rails_7_2
#
# PostgreSQL connection settings come from the libpq variables. With Docker:
#
#   docker run -d --name cpor-pg -e POSTGRES_PASSWORD=postgres -p 55432:5432 postgres:16
#   E2E_POSTGRESQL=1 PGHOST=127.0.0.1 PGPORT=55432 PGUSER=postgres PGPASSWORD=postgres \
#     specs_e2e/transactional_server_smoke.sh specs_e2e/rails_7_2
#
# The pg gem is in the sample apps' optional :postgresql group, so install the
# bundle with BUNDLE_WITH=postgresql (this script exports it).
set -eo pipefail

cd "$1"
export RAILS_ENV=test
export BUNDLE_GEMFILE="$PWD/Gemfile"
if [ "$E2E_POSTGRESQL" = "1" ]; then
  export BUNDLE_WITH=postgresql
  bundle install --quiet --retry 2
fi

databases="sqlite3"
if [ "$E2E_POSTGRESQL" = "1" ]; then databases="sqlite3 postgresql"; fi

for database in $databases; do
  echo "-- transactional server smoke test on $database (Puma with more than one thread)"
  # Boots a real server through CypressOnRails::Server with transactional_server
  # enabled and is bounded by its own timeout, so a hang fails instead of
  # blocking CI.
  E2E_DATABASE=$database bundle exec ./bin/rails db:drop || true
  E2E_DATABASE=$database bundle exec ./bin/rails db:create db:migrate
  E2E_DATABASE=$database RAILS_MAX_THREADS=3 bundle exec ./bin/rails runner ../transactional_server_smoke_test.rb
done
