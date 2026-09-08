# Naming Decision: E2E on Rails

## Status

Decision: rename the project to **E2E on Rails** and use **e2eonrails.com** as the canonical docs domain.

## Decision summary

| Item | Decision |
| --- | --- |
| Public name | **E2E on Rails** |
| GitHub repository | `shakacode/e2e-on-rails` |
| New v2 gem | `e2e_on_rails` |
| Legacy gem | Keep `cypress-on-rails` as the compatibility/deprecation path |
| Docs domain | `e2eonrails.com` |
| Defensive domains | Do **not** buy variants unless the project later becomes a larger commercial product |
| Tagline | The Rails test bridge for Cypress and Playwright. |

## One-sentence positioning

**E2E on Rails lets Cypress and Playwright tests use your real Rails test setup: FactoryBot, fixtures, database cleanup, scenarios, VCR, and custom app commands.**

## Domain decision

Use one canonical domain:

```text
e2eonrails.com
```

Do **not** defensively register variants right now:

```text
e2erails.com
railse2e.com
e2e-on-rails.com
e2eonrails.dev
e2eonrails.org
rails-e2e.com
```

Reasoning:

- The strongest assets for an OSS gem are the GitHub repo, gem name, README, RubyGems page, and ShakaCode authority.
- The domain matters, but it does not justify domain clutter.
- `e2eonrails.com` matches the brand phrase **E2E on Rails** exactly.
- `e2erails.com` is shorter, but it reads like a clipped category phrase, “E2E Rails,” not the project name.
- `railse2e.com` is useful as a keyword phrase, but it reverses the brand and feels more generic.
- The word **on** is valuable because it connects this project to the naming lineage of **React on Rails** and **Cypress on Rails**.

## Domain usage

Make the apex domain the docs and landing page:

```text
e2eonrails.com
```

Do not start with a separate docs subdomain:

```text
docs.e2eonrails.com
```

For an OSS gem, the docs homepage can also be the marketing homepage. A separate marketing site can be added later only if the project becomes more commercial.

Recommended docs structure:

```text
/
  What is E2E on Rails?
/getting-started
/cypress
/playwright
/factory-bot
/fixtures
/scenarios
/app-commands
/migration/from-cypress-on-rails
```

Renewal rule: keep the domain after the first year only if it has real value, such as docs, README links, RubyGems links, backlinks, search traffic, or product value. Otherwise, fold the docs back under ShakaCode and let the domain expire.

## Why this name

The current repo name, `cypress-playwright-on-rails`, is accurate but too long and tool-list-like. It also risks aging poorly if another browser automation tool becomes important later.

The old name, `cypress-on-rails`, made sense when the project was Cypress-specific. Today, the project supports both Cypress and Playwright, so leading with “Cypress” under-sells the broader purpose.

**E2E on Rails** is stronger because it is:

- Short and memorable.
- Searchable for “e2e tests rails”.
- Broad enough to cover Cypress, Playwright, and future browser runners.
- Clear to Rails developers that the project belongs in the Rails testing ecosystem.
- Clear to JavaScript/browser-test developers that this is about end-to-end testing, not just Rails system tests.
- Aligned with the existing ShakaCode naming pattern around Rails integration projects.

## Recommended tagline options

Primary tagline:

> The Rails test bridge for Cypress and Playwright.

Alternative taglines:

> Use Cypress or Playwright with your real Rails test setup.

> Rails-native test data, factories, fixtures, and app commands for modern browser tests.

> Bring Rails test power to Cypress and Playwright.

## Ecosystem notes

The name should avoid being locked to either Cypress or Playwright because existing gems already occupy those mental categories:

- `cypress-rails` is Cypress-specific.
- `playwright-on-rails` is Playwright-specific.
- `browser` is already a major Ruby gem name associated with browser detection, so names like `browser_on_rails` may be ambiguous.
- A plain `e2e` name is too broad and may conflict with other testing projects, so the full phrase **E2E on Rails** is stronger.

## Search positioning

The name should support these search intents:

- e2e tests rails
- browser tests rails
- playwright rails
- cypress rails
- rails test data cypress
- rails test data playwright
- factorybot cypress rails
- factorybot playwright rails

**E2E on Rails** gives the project a clean umbrella brand while the documentation can still target Cypress and Playwright keyword searches directly.

## Notes from issue #11: gem rename

Issue #11 proposed a rename toward the clearer `cypress_on_rails` / `CypressOnRails` naming style.

That direction was reasonable in 2019 because the project was still Cypress-centered. In the current state, however, adopting a Cypress-only name would not reflect Playwright support.

Decision from that issue, updated for today:

- Do not use `cypress_on_rails` as the new primary name.
- Keep `cypress-on-rails` as a legacy compatibility gem.
- Introduce `e2e_on_rails` as the forward-looking umbrella gem.

## Notes from issue #24: gem split

Issue #24 proposed splitting the gem into focused components, such as support for factories, fixtures, scenarios, and app-command execution.

That idea still makes sense architecturally, but the naming should now use the broader E2E brand instead of a Cypress-specific prefix.

Possible future split:

```ruby
gem "e2e_on_rails"                 # umbrella
gem "e2e_on_rails-cypress"         # Cypress adapter
gem "e2e_on_rails-playwright"      # Playwright adapter
gem "e2e_on_rails-factory_bot"     # FactoryBot support
gem "e2e_on_rails-fixtures"        # ActiveRecord fixture support
gem "e2e_on_rails-scenarios"       # scenario/app command support
```

Recommendation: start with one umbrella gem first. Splitting too early creates more maintenance, more documentation, and more decisions for adopters. Split later only if separate packages create a clear maintenance or adoption benefit.

## Migration plan

### Phase 1: Rename the public project

Rename the repo from:

```text
shakacode/cypress-playwright-on-rails
```

to:

```text
shakacode/e2e-on-rails
```

Update the README title:

```md
# E2E on Rails

The Rails test bridge for Cypress and Playwright.

Formerly cypress-on-rails.

Use Cypress or Playwright with your Rails test setup: FactoryBot, fixtures, database cleanup, scenarios, VCR, and custom app commands.
```

### Phase 2: Introduce the new gem

Add a new preferred gem:

```ruby
gem "e2e_on_rails"
```

Keep the existing gem working:

```ruby
gem "cypress-on-rails"
```

The legacy gem can either depend on `e2e_on_rails` or act as a compatibility wrapper.

### Phase 3: Launch the docs domain

Use:

```text
e2eonrails.com
```

as the canonical docs and landing page.

Link to this domain from:

- GitHub README.
- RubyGems page.
- ShakaCode site.
- Any migration notices in the legacy gem docs.

Do not buy defensive variants unless the project later has enough commercial gravity to justify the extra renewal overhead.

### Phase 4: Update documentation and examples

Update docs to lead with the umbrella concept:

```text
E2E on Rails supports Cypress and Playwright.
```

Then create runner-specific sections:

```text
Using E2E on Rails with Cypress
Using E2E on Rails with Playwright
```

This keeps the project name stable while preserving search visibility for both tools.

## Recommended README hero section

```md
# E2E on Rails

The Rails test bridge for Cypress and Playwright.

E2E on Rails lets modern browser tests use your real Rails test setup:
FactoryBot, fixtures, database cleanup, scenarios, VCR, and custom app commands.

Docs: https://e2eonrails.com

Formerly `cypress-on-rails`.
```

## Recommended docs homepage hero section

```md
# E2E on Rails

Cypress and Playwright tests with real Rails data, factories, fixtures, and app commands.

E2E on Rails is the Rails test bridge for modern browser automation. It lets your E2E tests reset the database, create records with FactoryBot, load fixtures, run scenarios, and call custom Rails-side commands.

[Get started](/getting-started)
```

## Names considered

| Rank | Name | Repo / gem shape | Assessment |
| ---: | --- | --- | --- |
| 1 | **E2E on Rails** | `e2e-on-rails` / `e2e_on_rails` | Best balance of catchy, searchable, and future-proof. |
| 2 | Rails E2E Bridge | `rails-e2e-bridge` / `rails_e2e_bridge` | Technically precise, but less elegant as a brand. |
| 3 | Rails Browser Kit | `rails-browser-kit` / `rails_browser_kit` | Good for “browser tests Rails,” but less clearly Cypress/Playwright/E2E. |
| 4 | Rails Test Bridge | `rails-test-bridge` / `rails_test_bridge` | Accurate architecture, but too broad for search. |
| 5 | Browser on Rails | `browser-on-rails` / `browser_on_rails` | Catchy, but “browser” is ambiguous in the Ruby ecosystem. |
| 6 | Rails E2E Kit | `rails-e2e-kit` / `rails_e2e_kit` | Clear, but less memorable than “E2E on Rails.” |

## Domain names considered

| Rank | Domain | Assessment |
| ---: | --- | --- |
| 1 | `e2eonrails.com` | Best match to the brand phrase **E2E on Rails**. Use this. |
| 2 | `e2erails.com` | Shorter, but sounds clipped and less connected to the “on Rails” brand pattern. |
| 3 | `railse2e.com` | Good keyword phrase, but weaker as a brand and reversed from the project name. |
| 4 | `e2e-on-rails.com` | Exact phrase with hyphens, but not worth another renewal. |
| 5 | `.dev` / `.org` variants | Not worth buying unless the project becomes a larger commercial product. |

## Names to avoid

Avoid `cypress-playwright-on-rails` as the long-term name. It is descriptive but too long and too tied to the current runner list.

Avoid `cypress_on_rails` as the new headline name. It solves the old rename problem but not the current multi-runner positioning problem.

Avoid `rails-system-tests-*` unless the goal is to position the project directly inside Rails’ native System Test / Capybara world. It is Rails-accurate but less compelling for Cypress and Playwright users.

Avoid buying multiple domain variants for the current OSS stage. The project does not need defensive domain clutter.

## Final recommendation

Rename the project to **E2E on Rails**.

Use:

```text
Project:  E2E on Rails
Repo:     shakacode/e2e-on-rails
Gem:      e2e_on_rails
Legacy:   cypress-on-rails
Docs:     e2eonrails.com
Tagline:  The Rails test bridge for Cypress and Playwright.
```

This name is short, searchable, runner-neutral, clear about the project’s Rails identity, and aligned with the `on Rails` naming pattern. The domain decision is intentionally simple: buy and use **e2eonrails.com**, and skip the defensive variants.
