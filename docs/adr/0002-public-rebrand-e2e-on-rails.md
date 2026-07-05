# ADR-0002: Public rebrand to "E2E on Rails"; gem flip is 2.0, scheduled after v1.22

Date: 2026-07-04
Status: Accepted (@justin808)
Amends: ADR-0001 (alias mechanics unchanged; brand scope and timing extended)

## Context

ADR-0001 reserved `e2e_on_rails` as a wrapper gem and deferred all renaming to
an unscheduled 2.0, with docs at testing.shakastack.com. A fuller naming
evaluation (see `docs/roadmap/2026-07-e2e-on-rails-naming-decision.md`,
adopted 2026-07-04) chose a complete public brand — **E2E on Rails** — and
**e2eonrails.com** was purchased the same day. Two ambiguities in that document
were resolved by the maintainer on 2026-07-04:

1. Its Phase 2 ("new preferred gem") did not date the gem flip.
2. Its Phase 1 (repo rename) did not sequence against the pending v1.21.0 release.

## Decision

1. **Brand now:** public name **E2E on Rails**; tagline
   *"The Rails test bridge for Cypress and Playwright."*
2. **Domain:** `e2eonrails.com` (purchased) is the canonical docs + landing
   page at the apex — no `docs.` subdomain, no defensive domain variants.
   Supersedes the testing.shakastack.com plan from ADR-0001/roadmap S2.
   Renewal rule per the naming doc: keep after year one only if it carries
   real traffic/links; otherwise fold docs back under ShakaCode.
3. **Repo rename** to `shakacode/e2e-on-rails` **immediately after v1.21.0
   ships** (GitHub redirects old URLs), together with the README hero from the
   naming doc ("Formerly `cypress-on-rails`") and a sweep of gemspec/badge/
   workflow/docs URLs. The v1.21.0 release itself runs under the current name.
4. **Gem flip is 2.0, and 2.0 is scheduled**: right after the v1.22 line
   (hardening #185/#186/#13 + migration guide #220) lands — target ~2–3
   months out. At 2.0: code moves to `e2e_on_rails`, `cypress-on-rails`
   becomes the compatibility shim, module renames to `E2eOnRails` with a
   `CypressOnRails` deprecation alias. Until then `e2e_on_rails` stays the
   thin wrapper from ADR-0001 (#226) and install instructions keep saying
   `gem 'cypress-on-rails'`, so cypress-rails migrants experience exactly one
   rename event.
5. **No gem split** (reaffirms closing #24); if a split ever happens it uses
   the `e2e_on_rails-*` prefix per the naming doc.

## Stats preservation (explicit guarantee, added 2026-07-04)

Nothing in this rebrand discards accumulated social proof or history:

- **GitHub:** the rename (#228, pending — gated on v1.21.0 shipping) must be
  an in-place GitHub rename — stars, forks, watchers, issues, PRs, and traffic
  history all carry over, and old URLs/git remotes redirect permanently. Precedent: this repo already renamed once
  (cypress-on-rails → cypress-playwright-on-rails) and lost nothing.
  Do NOT create a fresh repo and archive the old one; that WOULD lose stats.
- **RubyGems:** `cypress-on-rails` is never yanked. It remains the real gem
  through 1.x and the published shim from 2.0 onward, so its ~6.4M download
  history stays visible and keeps growing (shim installs also pull
  `e2e_on_rails`, so the new gem accrues its own count on top). Marketing and
  README cite the lineage: "6.4M+ downloads as cypress-on-rails".

## Consequences

- Docs-site work (#221/#222 outputs, migration guide #220) publishes to
  e2eonrails.com with the IA from the naming doc
  (`/getting-started`, `/cypress`, `/playwright`, `/factory-bot`, `/fixtures`,
  `/scenarios`, `/app-commands`, `/migration/from-cypress-on-rails`).
- The v1.22 outreach (#224) leads with the E2E on Rails brand while still
  instructing `gem 'cypress-on-rails'` — the guide must say the 2.0 name
  change is coming and that the shim will keep old Gemfiles working.
- A 2.0 flip checklist issue tracks the inversion; the wrapper gem (#226)
  ships with e2eonrails.com metadata so its RubyGems page is on-brand from
  day one.
