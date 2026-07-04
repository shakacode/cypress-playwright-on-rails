# Context

Canonical vocabulary for this project. If a term here conflicts with usage in
an issue, PR, or doc, this file wins; update it deliberately, not incidentally.

## Naming (resolved 2026-07-04, see ADR-0001)

| Term | Meaning |
|---|---|
| `cypress-on-rails` | The published gem name through the 1.x line. Canonical in Gemfiles today. |
| `e2e_on_rails` | Reserved alias gem (thin wrapper depending on `cypress-on-rails`). Becomes the canonical gem name at 2.0, with `cypress-on-rails` becoming the compatibility shim. |
| `CypressOnRails` | The Ruby module namespace through 1.x. Renames (to `E2eOnRails`, with a deprecation alias) only at 2.0. |
| `cypress-playwright-on-rails` | The GitHub repository name. Not a gem name; do not use it in Gemfiles. |
| Docs site | `testing.shakastack.com` (decision 2026-07-04). No dedicated domain unless/until the 2.0 rename ships. |

## Core domain terms

| Term | Meaning |
|---|---|
| install folder | The app-side directory (default `e2e/`, config `install_folder`) holding `e2e_helper.rb`, `app_commands/`, and framework config. Since v1.20.0, helper and commands live at its **root**, not inside `cypress/`. |
| app command | A Ruby file in `app_commands/` executed in the Rails process when a test calls `cy.app(...)` / `app(...)`. The middleware's unit of remote execution. |
| scenario | An app command under `app_commands/scenarios/` that seeds a named state, invoked via `cy.appScenario(...)`. |
| middleware | `CypressOnRails::Middleware`, mounted outside production only, serving the `__e2e__` (legacy `__cypress__`) API prefix. Executes arbitrary Ruby by design — see README security model and issue #13. |
| managed server | The Rails server started/stopped by the `cypress:*` / `playwright:*` rake tasks (since v1.19.0), with lifecycle hooks (`before_server_start`, …, `before_server_stop`). |
| transactional server | `transactional_server` mode wrapping the run in a rolled-back DB transaction, reset via `/cypress_rails_reset_state` (cypress-rails-compatible endpoint). |
