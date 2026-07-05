# Context

Canonical vocabulary for this project. If a term here conflicts with usage in
an issue, PR, or doc, this file wins; update it deliberately, not incidentally.

## Naming (resolved 2026-07-04, see ADR-0001 + ADR-0002)

| Term | Meaning |
|---|---|
| **E2E on Rails** | The public/brand name of the project (ADR-0002). Tagline: "The Rails test bridge for Cypress and Playwright." |
| `cypress-on-rails` | The published gem name through the 1.x line. Canonical in Gemfiles until 2.0, then the compatibility shim. |
| `e2e_on_rails` | Thin wrapper gem today (#226); the canonical gem from 2.0. 2.0 is scheduled right after the v1.22 line ships. |
| `CypressOnRails` | The Ruby module namespace through 1.x. Renames to `E2eOnRails` (with a `CypressOnRails` deprecation alias) at 2.0. |
| `cypress-playwright-on-rails` | Current GitHub repository name; renames to `shakacode/e2e-on-rails` immediately after v1.21.0 ships (GitHub redirects). Never a gem name. |
| `e2eonrails.com` | Purchased 2026-07-04. Canonical docs + landing page at the apex (no `docs.` subdomain, no defensive variants). Supersedes the earlier testing.shakastack.com plan. |

## Core domain terms

| Term | Meaning |
|---|---|
| install folder | The app-side directory (default `e2e/`, config `install_folder`) holding `e2e_helper.rb`, `app_commands/`, and framework config. Since v1.20.0, helper and commands live at its **root**, not inside `cypress/`. |
| app command | A Ruby file in `app_commands/` executed in the Rails process when a test calls `cy.app(...)` / `app(...)`. The middleware's unit of remote execution. |
| scenario | An app command under `app_commands/scenarios/` that seeds a named state, invoked via `cy.appScenario(...)`. |
| middleware | `CypressOnRails::Middleware`, mounted outside production only, serving the `__e2e__` (legacy `__cypress__`) API prefix. Executes arbitrary Ruby by design — see README security model and issue #13. |
| managed server | The Rails server started/stopped by the `cypress:*` / `playwright:*` rake tasks (since v1.19.0), with lifecycle hooks (`before_server_start`, …, `before_server_stop`). |
| transactional server | `transactional_server` mode wrapping the run in a rolled-back DB transaction, reset via `/cypress_rails_reset_state` (cypress-rails-compatible endpoint). |
