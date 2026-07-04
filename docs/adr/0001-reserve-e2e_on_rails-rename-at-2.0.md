# ADR-0001: Reserve `e2e_on_rails` as an alias gem now; full rename at 2.0

Date: 2026-07-04
Status: Accepted (@justin808)

## Context

The gem is named `cypress-on-rails` but has supported Playwright since v1.15.0,
and its internal vocabulary already moved to framework-neutral "e2e" (`__e2e__`
API prefix, `e2e/` install folder, `e2e_helper.rb`). Playwright users cannot
find the gem by name; the name also misstates the product while we court
users of the dormant cypress-rails gem.

Constraints discovered during evaluation (2026-07-04):

- `playwright-on-rails` is already taken on RubyGems by an unrelated gem —
  evidence that candidate names get claimed.
- `e2e_on_rails`, `e2e-on-rails`, and `rails-e2e` were all unclaimed.
- `cypress-on-rails` has 6.4M lifetime downloads of brand equity, and a rename
  mid-1.x would churn Gemfiles exactly while we are pitching stability to
  cypress-rails migrants (issues #220/#224).

## Decision

1. Publish **`e2e_on_rails`** now as a thin wrapper gem: it pins
   `cypress-on-rails` to the current minor and its require file loads
   `cypress_on_rails`. Version mirrors the parent gem. This secures the name
   and gives "e2e rails" searchers a working install path immediately.
2. Underscore spelling (`e2e_on_rails`) per RubyGems convention for standalone
   gems, matching the future `E2eOnRails` module; chosen over family
   consistency with the dash in `cypress-on-rails`.
3. At **2.0** (no date set): `e2e_on_rails` becomes the canonical gem;
   `cypress-on-rails` becomes the compatibility shim; module renames to
   `E2eOnRails` with a `CypressOnRails` deprecation alias.
4. No docs domain purchase until the 2.0 flip; docs live at
   testing.shakastack.com (see roadmap S2).

## Consequences

- Two gems to bump per release (wrapper bump is scriptable in the release task).
- Dual branding in docs ("cypress-on-rails, becoming e2e_on_rails") until 2.0.
- The 2.0 module rename is the expensive, breaking part and stays deferred;
  nothing in 1.x may depend on the new name existing.
- Alternatives rejected: full rename now (Gemfile churn during the migration
  campaign); status quo (leaves the name claimable by others, as happened
  with `playwright-on-rails`).
