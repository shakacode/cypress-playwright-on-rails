# Shaka configuration

| Identifier | Value |
| --- | --- |
| Package / skill SemVer | `0.1.0-pre.1` |

The configured `repo_prefix: CPOR` labels Shaka task titles. The `shaka` helper
comes from the installed Shaka skill; repository setup, test, and validation
commands stay under `.agents/bin/`.

This records the Shaka package / skill SemVer. The typed contract is in
`agent-workflow.yml`; its `version` identifies the schema. `../AGENTS.md` owns
repository identity, untrusted-contributor boundaries, and human-only delivery rules.

## Check configuration edits

For a local configuration edit on a trusted checkout, run from the repository root:

`shaka seam check --root . --local`

This checks the current checkout's YAML and fixed command paths and executable
bits. It does not execute wrappers or grant trusted policy authority. For PR
work, follow `AGENTS.md`: resolve the trusted default branch and use
`shaka seam check --root . --ref SHA` before inspecting and running candidate
commands. Never use `--local` to establish trust in PR content.

- [Configuration reference](https://github.com/shakacode/shaka/blob/8431a718cfd91e9ce7cb4276baae076848e05d13/docs/settings.md) — every key, its type, and what it controls.
- [Repository setup](https://github.com/shakacode/shaka/blob/8431a718cfd91e9ce7cb4276baae076848e05d13/docs/configure-repository.md) — how this directory was created.
