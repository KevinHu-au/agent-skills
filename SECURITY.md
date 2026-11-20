# Security policy

## Supported versions

Only the `main` branch is supported. This repository has no releases or tags. Fixes go to `main` only, so pull
the latest `main` and re-run `./install.sh --apply` to get them.

## How to report a vulnerability

Use GitHub private vulnerability reporting. Do not open a public issue or pull request for a security problem.

1. Open the [Security tab](https://github.com/KevinHu-au/agent-skills/security) of this repository.
2. Choose **Report a vulnerability**, or go straight to
   [the new advisory form](https://github.com/KevinHu-au/agent-skills/security/advisories/new).
3. Include:
   - the tool and its version: Claude Code, Copilot CLI or Codex;
   - your operating system, and the shell on Windows (for example Git Bash);
   - the exact command, prompt or input that shows the problem;
   - what happened, and what you expected to happen.

This is a one-person project. Replies are best effort.

## Scope

In scope:

- The shell safety hook, `hooks/copilot/block-dangerous-shell.sh`. This covers its rules, the gate that decides
  whether a session is checked, the marker files in `~/.agents/hook-state/`, and the
  [always-on guard](README.md#always-on-guard-optional). An example is a dangerous command form that the hook
  should catch by its own rules but lets through.
- `global/bin/rm-scratch`. An example is a removal of a path that the script should refuse: a path outside the
  system temp folders, a symlink, or a path you do not own.
- `install.sh`. Examples are a write outside the paths the README documents, any delete, or an edit to a live
  settings file such as `~/.claude/settings.json`.
- The `agentd-data-fix` skill. The skill writes scripts in chat and never runs anything against a database. An
  example is skill text that makes the agent run a script, or a generated guard or reverse script that fails
  without saying so.
- Prompt injection through the skills. An example is text in a repository, work item or file that makes an
  agentd skill drop its guards or act without asking you first.

Out of scope:

- Bugs in Claude Code, Copilot CLI or Codex themselves. Report those to each vendor.
- Command forms that the README already lists as not caught.
- A false deny or ask caused by a command word inside quoted text. The README accepts this as safe.

## The hook is a guard rail, not a sandbox

The shell safety hook matches commands with regular expressions. A regex cannot catch every shell form. The
README lists the forms it does not catch, such as a command in a variable, a git alias, or a script run with
`bash script.sh`. See [Rules](README.md#rules) under the shell safety hook.

By default, the hook checks commands only inside an agentd skill. Do not rely on it as your only control. The
strongest protection against an unwanted push does not depend on any agent: turn on branch protection for the
main branches on the remote server.
