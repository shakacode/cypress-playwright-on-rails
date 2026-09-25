# Agent Workflow Scripts

Standard entry points that portable agent-workflow skills call. A script that
is absent means that capability is n/a in this repository.

| Script | Purpose | This repo runs |
| --- | --- | --- |
| `setup` | Install dependencies | `bundle install` |
| `validate` | Pre-push gate | `bundle exec rake ci` (specs + lint + newlines; no filter arguments) |
| `test` | Run tests | `bundle exec rake` (default core spec suite), or `bundle exec rspec <spec path[:line]>` for focused tests |
| `lint` | Lint / format | `bundle exec rake lint check_newlines` (RuboCop + trailing newlines) |
| `build` | Build / type-check | n/a |
| `docs` | Docs checks | n/a |
| `ci-detect` | CI change detector | n/a |

Typed workflow settings live in [`../agent-workflow.yml`](../agent-workflow.yml).
Repository trust, review, and merge rules live in [`../../AGENTS.md`](../../AGENTS.md).

For focused examples, pass relative `*_spec.rb` paths below `spec/` to
`.agents/bin/test`. RSpec's `:line` filter is supported. The wrapper rejects
paths that resolve outside `spec/`. Without paths, it runs the default Rake core
suite.

`validate` runs `rake ci` rather than the default `rake` task because CI
enforces linting and trailing newlines as well as the specs (see
`.github/workflows/lint.yml`); a specs-only gate would pass branches that CI
then rejects. `test` stays on the default `rake` task, which is the core spec
suite on its own.
