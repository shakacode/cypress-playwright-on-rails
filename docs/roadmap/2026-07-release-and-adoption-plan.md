# Release & Adoption Plan — July 2026

Status: PROPOSED (triage applied to GitHub 2026-07-03; everything else awaits maintainer sign-off)
Owner: @justin808
Audience: maintainers **and coding agents**. Every task below is written to be
implementable by an agent without additional context. Facts were verified on
2026-07-03; re-verify anything marked VERIFY before acting on it.

---

## 1. Current state (verified 2026-07-03)

| Fact | Value |
|---|---|
| Gem name | `cypress-on-rails` (repo renamed to `cypress-playwright-on-rails`) |
| Latest RubyGems release | 1.20.0 (2025-10-21) |
| Lifetime downloads | 6,412,456 |
| GitHub stars / forks | 453 / 61 |
| Latest **GitHub Release** | v1.15.0 (2023-07-05) — 5 versions behind RubyGems |
| Unreleased commits on master | 7 (notably Rails 8.1 compat fix #207, generator whitespace fix #205) |
| Open issues / PRs | 21 / 6 (all triage-labeled as of 2026-07-03) |

### The competitive moment (why now)

[testdouble/cypress-rails](https://github.com/testdouble/cypress-rails) is
**effectively dormant**:

- Last commit to main: 2024-09-06 (v0.7.1). Last maintainer activity of any kind: Nov 2024.
- **Broken on Rails 7.2+** ([testdouble/cypress-rails#164](https://github.com/testdouble/cypress-rails/issues/164), 31 comments):
  `ConnectionPool#lock_thread=` was removed in Rails 7.2. The only fix is
  0.8.0.rc1, which was never finalized and causes state-reset failures / Puma
  hangs for some users. Users are on personal forks or stuck.
- 1.19M lifetime downloads (0.8.0.rc1 alone has 189k — an active, stranded CI user base).
- No Playwright support, none planned. Justin Searls publicly moved to
  Playwright for Rails browser testing (justin.searls.co, June 2024).

cypress-on-rails **v1.19.0 already shipped the parity features** those users
would need: `cypress:open`/`cypress:run` rake tasks, automatic server
start/stop, `before_server_start`/`after_server_start`/`after_transaction_start`/`after_state_reset`/`before_server_stop`
hooks, transactional test mode, the `/cypress_rails_reset_state` endpoint, and
`CYPRESS_RAILS_HOST`/`CYPRESS_RAILS_PORT` env vars. What's missing is
**hardening (issue #185), a migration guide, and marketing**.

⚠️ **Strategic caveat:** cypress-rails died from a fragile transactional-server
implementation under multi-threaded Puma. Our equivalent (merged in v1.19.0 via
PR #179) has known robustness gaps tracked in **#185** and **#186**. Harden
before marketing the migration path — attracting refugees onto a launcher that
hangs would repeat the failure we're recruiting from.

### ShakaStack fit (from shakastack.com research)

- shakastack.com pitches "Ship modern React in Rails — fast, and prove it"
  (Build → Deploy → Prove) and claims "the most agent-capable stack".
  **The Prove phase currently only covers performance (ShakaPerf). E2E
  correctness — this gem — is absent from shakastack.com and shakacode.com.**
- react_on_rails already dogfoods this gem (its dummy-app E2E suite runs
  Playwright *via cypress-on-rails*: `react_on_rails/spec/dummy/e2e/README.md`) — an
  untold story.
- Ecosystem conventions this repo doesn't yet follow: `AGENTS.md`
  (contributor agents) + `AGENTS_USER_GUIDE.md` (users' agents) + `llms.txt`
  (react_on_rails has all three), a `doctor` diagnostic task
  (react_on_rails/shakapacker have one), a brief top-level README with docs
  links (ours is 821 lines with the consulting block above the fold).

---

## 2. Triage results (labels applied 2026-07-03)

New labels created: `documentation`, `security`, `needs-info`,
`close-candidate`, `needs-rebase`, `needs-decision`, `priority: high`,
`priority: medium`, `priority: low`, `agent-ready`, `cypress-rails-parity`,
`ci-infra`.

### PRs — recommended actions

| PR | State | Action |
|---|---|---|
| [#210](https://github.com/shakacode/cypress-playwright-on-rails/pull/210) Don't override RAILS_ENV | Approved, CI green, mergeable | **Merge now.** Ships in v1.21.0 |
| [#168](https://github.com/shakacode/cypress-playwright-on-rails/pull/168) Playwright `response.json()` fix | Approved but conflicting, +6/−3 | **Rebase, re-run CI, merge.** Ships in v1.21.0 (task R3) |
| [#213](https://github.com/shakacode/cypress-playwright-on-rails/pull/213) Claude workflow | Conflicting; superseded by merged #211/#212/#214/#215 | **Close** as superseded |
| [#193](https://github.com/shakacode/cypress-playwright-on-rails/pull/193) RuboCop | Changes requested, large | Keep; land after v1.21.0 to avoid churn (issue #197 tracks follow-ups) |
| [#191](https://github.com/shakacode/cypress-playwright-on-rails/pull/191) Release task conflict | Conflicting, CI red, changes requested | Rebase or close/redo small; only touch alongside the release (task R6) |
| [#173](https://github.com/shakacode/cypress-playwright-on-rails/pull/173) README: run server in test env | Conflicting; overlaps #210 and #157 | Decide docs stance on test-env (task M4), then rebase or close |

### Issues — close candidates (resolved by shipped releases or stale)

| Issue | Why closable | Close message should point to |
|---|---|---|
| #152 Auto-start rails server | Shipped in v1.19.0 (rake tasks + managed server) | CHANGELOG 1.19.0, `docs/` |
| #153 Initialization hooks | Shipped in v1.19.0 (all 5 hooks it asked for) | CHANGELOG 1.19.0 |
| #112 Integration tests Rails 6/7 | CI now covers Rails 6.1–8.x example apps; Rails 4/5 dropped in 1.18.0 | `.github/workflows/ruby.yml` |
| #92 Stub outgoing requests | VCR middleware shipped in 1.18.0 covers this | `docs/VCR_GUIDE.md` |
| #183 v1.19.0 release discussion | Release shipped 2025-10-01 | — |
| #146 Webpack compilation error | Stale (2023), Cypress-side config, no repro | — |
| PR #213 | Superseded (see above) | merged #211–#215 |

**Agent instruction:** when closing, post a comment naming the release that
resolved it and the doc to read; invite reopening if the shipped feature
doesn't cover the reporter's case. Do not close silently.

### Issues — keep open, prioritized

| Priority | Issue | Notes |
|---|---|---|
| high | #185 server/state-reset hardening | Prerequisite for migration campaign (task H1) |
| high | #13 RCE mitigation / middleware security | Long-standing adoption blocker; see task H3 |
| medium | #186 follow-ups from PR #180 review | Small, `agent-ready` |
| medium | #114 transactional fixtures | Partially addressed by v1.19 transactional mode; remaining: document + benchmark vs database_cleaner |
| medium | #157 test-env reloading | Docs task M4; related to merged #210 |
| medium | #78 TypeScript typings | `agent-ready`, task A4 |
| medium | #80 Devise login helper, #81 ActionMailer email viewing | Good v1.22+ features, `agent-ready` |
| low | #113 split experimental options, #197 RuboCop staging, #209 Lefthook | Housekeeping |
| needs-info | #175 VCR route 404, #155 MySQL error | Ask for repro; auto-close in 30 days if silent |
| needs-decision | #24 gem split (2019), #11 gem rename (2019) | Maintainer decision; recommend closing both as "won't do — stability is the brand" |

---

## 3. Release plan

### v1.21.0 — "current & compatible" (target: within 2 weeks)

Goal: flush 9 months of unreleased fixes, restore release hygiene, signal
active maintenance to anyone comparing us with cypress-rails.

Contents: Rails 8.1 compat (#207), generator whitespace (#205), PR #210
(RAILS_ENV respected), PR #168 (Playwright JSON response fix).

Tasks (each independently implementable; IDs referenced below):

- **R1 — Merge PR #210.** Verify CI green on a rebase against master first.
  Changelog entry under `### Changed`: server no longer overrides a
  pre-set `RAILS_ENV`.
- **R2 — Rebase + merge PR #168.** Conflict is in
  `lib/generators/cypress_on_rails/templates/spec/e2e/e2e_helper.rb.erb` area
  (playwright helper templates). After rebase, run the Playwright example app
  CI job. Note in CHANGELOG under `### Fixed`. Credit @helio3197.
- **R3 — CHANGELOG pass.** Move the `[Unreleased]` folder-structure section
  (#201/#203) under `## [1.20.0]` — verified: commit 73961af is inside the
  v1.20.0 tag but its entry was left under Unreleased. Add entries for
  #205, #207, #210, #168.
- **R4 — Release.** Follow `RELEASING.md` (`rake release[1.21.0]`,
  gem-release based). Requires RubyGems + git push credentials (human step).
- **R5 — Backfill GitHub Releases** for v1.16.0, v1.17.0, v1.18.0, v1.19.0,
  v1.20.0, v1.21.0 from CHANGELOG sections
  (`gh release create v1.XX.0 --title "vX.XX.0" --notes-file <extract>`).
  Rationale: the repo currently advertises "Latest release v1.15.0 · 2023" —
  reads as abandoned, which is fatal when courting cypress-rails refugees.
- **R6 — Fix the release task** (PR #191's goal) only if R4 actually hits the
  duplicate-task conflict; otherwise close #191 and note the finding.

### v1.22.0 — "the cypress-rails magnet" (target: +4–6 weeks)

Theme: harden the server/transactional path, then actively convert
cypress-rails users.

- **H1 (issue #185) — server & state-reset hardening.** `priority: high`.
  Scope from the issue: spawn-failure error handling, SIGTERM→SIGKILL
  escalation with timeout, port-detection retry, process-group cleanup, and
  tests for `lib/cypress_on_rails/server.rb` +
  `lib/cypress_on_rails/state_reset_middleware.rb`. Acceptance: new specs
  covering each failure mode; multi-threaded Puma smoke test in one example
  app (this is the exact failure mode that killed cypress-rails — see
  testdouble/cypress-rails#164).
- **H2 (issue #186) — PR #180 review follow-ups.** Small; do with H1.
- **H3 (issue #13) — security hardening.** Add an opt-in shared-secret token
  check to the middleware (`c.middleware_token = ENV[...]`; requests without
  the header 403) + README warning rewrite. Do NOT enable middleware outside
  dev/test by default (already the case — `use_middleware = !Rails.env.production?`;
  VERIFY current default in `lib/cypress_on_rails/configuration.rb`).
- **M1 — `docs/MIGRATE_FROM_CYPRESS_RAILS.md`.** The centerpiece. Structure:
  1. Why (dormant since 2024, Rails 7.2+ broken, no Playwright — with links);
  2. Concept map table (their env vars/hooks/reset endpoint → ours; most map 1:1 since v1.19.0);
  3. Step-by-step swap (Gemfile, generator, initializer);
  4. What you gain (factories from JS, `appEval`, scenarios, VCR, Playwright);
  5. Honest trade-offs (middleware security model + mitigation from H3).
  Acceptance: a real cypress-rails example app converted by following only the
  guide, committed under `specs_e2e/` as a CI job if practical.
- **M2 — README repositioning.** Add "Migrating from cypress-rails" link near
  the top; add a short comparison table; move the ShakaCode consulting block
  below the fold (match current react_on_rails/shakapacker style); add badges
  (gem version, downloads, CI).
- **M3 — Outreach (human, not agent):** ShakaCode blog post
  ("cypress-rails is stuck on Rails 7.1 — here's the maintained path, with
  Playwright"), a respectful comment on testdouble/cypress-rails#164
  pointing to M1, Reddit/r/rails + Rails Discord, changelog.com pitch.
- **M4 — Test-env docs (issue #157, PRs #173/#210).** Document the two
  supported modes (dev-env with `ENV['CYPRESS']` vs test-env with code
  reloading enabled) in README + `docs/`; then close #157 and resolve #173.

### v1.23.0 — "agent-native E2E" (target: +2–3 months)

Theme: make this the E2E layer AI agents reach for — aligned with
ShakaStack's "most agent-capable stack" claim. E2E-with-app-state-control is
uniquely agent-friendly: an agent can seed state via `app_commands`, run one
spec headlessly, and get a deterministic pass/fail without clicking around.

- **A1 — `AGENTS.md`** (contributor-facing; mirror
  react_on_rails/AGENTS.md structure; reuse shakacode/agent-workflows seams).
- **A2 — `AGENTS_USER_GUIDE.md` + `llms.txt`** (user-facing: how an agent in a
  host app should install, generate, seed state, run one test headlessly,
  interpret failures; publish llms.txt wherever docs land per S2).
- **A3 — `rails g cypress_on_rails:doctor` or `rake cypress_on_rails:doctor`.**
  Checks: middleware mounted? install_folder exists & matches config? VCR
  middleware on if vcr commands present (would have prevented issue #175)?
  server bootable? Print actionable fixes. Convention match: react_on_rails
  doctor / shakapacker doctor.
- **A4 (issue #78) — TypeScript declarations** for `cy.app*` commands, shipped
  via generator or `@types/`-style package. `agent-ready`.
- **A5 — machine-readable failure output.** Ensure middleware errors return
  structured JSON (error class, message, backtrace head) so agents can
  self-correct; document in A2.
- Candidates from backlog as capacity allows: #80 (devise helper),
  #81 (mailer deliveries endpoint), #114 (document/benchmark transactional mode
  vs database_cleaner).

---

## 4. ShakaStack integration (parallel track, mostly non-repo work)

- **S1 — shakastack.com:** add cypress-playwright-on-rails as a Projects card
  and extend "Prove" to two legs: *prove it's fast* (ShakaPerf) + *prove it
  works* (this gem). Owner: whoever edits shakastack.com (site repo UNKNOWN —
  locate first).
- **S2 — docs-site decision (needs @justin808):** dedicated domain
  (cypressplaywrightonrails.com? testing.shakastack.com?) vs polished in-repo
  docs. Every sibling project has a domain; recommendation: cheap
  subdomain-on-shakastack option to start.
- **S3 — cross-promotion:** react_on_rails already uses this gem for its E2E
  suite — write that up (blog or docs page "How React on Rails tests itself
  with Playwright"), link from react_on_rails docs and AGENTS_USER_GUIDE.
- **S4 — naming decision (needs @justin808, closes #11/#24):** repo is
  `cypress-playwright-on-rails`, gem is `cypress-on-rails`, brand is split.
  Options: (a) status quo, (b) rename gem with alias. Recommendation: (a) for
  now — 6.4M downloads of brand equity; revisit only with a 2.0.

---

## 5. Decisions needed from @justin808

1. Approve merge order R1/R2 and the v1.21.0 scope.
2. Approve closing the 7 close-candidates (§2) with the prescribed comments.
3. Close or keep #24 (gem split) and #11 (rename) — recommendation: close both.
4. Docs-site decision (S2).
5. Outreach tone for the cypress-rails#164 comment (M3) — draft before posting.
6. Whether #191/#193 (release task, RuboCop) land before or after v1.21.0
   (recommendation: after, to keep the release diff minimal).

## 6. Suggested agent execution order

```
R3 → R1 → R2 → R4(human) → R5        # v1.21.0, ~1 day of agent work + release
H1 → H2 → H3 → M1 → M2 → M4          # hardening before marketing
A1 → A2 → A3 → A4 → A5               # agent-native layer
S1–S4 in parallel (site/marketing, human-led)
```

Every task above states its issue/PR, files, and acceptance criteria; tasks
labeled `agent-ready` on GitHub carry the same contract. When in doubt:
small PRs, `bundle exec rubocop` clean, CHANGELOG entry per user-visible
change, files end with newline.
