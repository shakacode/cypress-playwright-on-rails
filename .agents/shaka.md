# Shaka configuration

| Identifier | Value |
| --- | --- |
| Package / skill SemVer | `0.1.0-pre.1` |

This records the Shaka package / skill SemVer. The typed contract is in
`agent-workflow.yml`; its `version` identifies the schema. `../AGENTS.md` owns
repository identity, untrusted-contributor boundaries, and human-only delivery rules.

## Check configuration edits

Run from the repository root:

`shaka seam check --root . --local`

Checks the current checkout's YAML and fixed command paths and executable bits. It
does not execute the wrappers and grants no trusted policy authority.

- [Configuration reference](https://github.com/shakacode/shaka/blob/8431a718cfd91e9ce7cb4276baae076848e05d13/docs/settings.md) — every key, its type, and what it controls.
- [Repository setup](https://github.com/shakacode/shaka/blob/8431a718cfd91e9ce7cb4276baae076848e05d13/docs/configure-repository.md) — how this directory was created.
