# e2e_on_rails

A thin alias gem with no code of its own. It depends on exactly the same version
of [`cypress-on-rails`](https://github.com/shakacode/cypress-playwright-on-rails),
and `require "e2e_on_rails"` simply requires that gem.

It exists to reserve this project's future canonical name. The project is
rebranding to **E2E on Rails** (https://e2eonrails.com); at 2.0 `e2e_on_rails`
becomes the real gem and `cypress-on-rails` becomes the compatibility shim.
Rationale: `docs/adr/0001-reserve-e2e_on_rails-rename-at-2.0.md` and
`docs/adr/0002-public-rebrand-e2e-on-rails.md`.

Until 2.0, use `cypress-on-rails` directly if you are unsure — that is still
the documented install path.
