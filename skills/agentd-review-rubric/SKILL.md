---
name: agentd-review-rubric
description: Use when the project has no review rubric, or the engineer wants to write or refresh one. Drafts review-rubric.md from the repository's own norms and the engineer's answers, lets the engineer correct it, and saves it. Needs no onboarding pack. Edits no code.
disable-model-invocation: true
---

# agentd-review-rubric

Write the project's review rubric: the criteria a reviewer checks on top of the general review rules. The result is one
file, `review-rubric.md`, in the shape of `references/rubric-template.md`. The engineer corrects the draft before it is
saved. The file belongs to the team: this skill writes it, and other skills only read it.

## Prerequisite

Run `git rev-parse --show-toplevel`. If it fails, stop with one line: `agentd-review-rubric needs a git repository. Run
it inside one.` Work from the repository root.

**Find an existing rubric.** Look in this order and stop at the first hit:

1. a `## Review rubric` section in `AGENTS.md`;
2. `docs/onboarding/review-rubric.md`;
3. `review-rubric.md` in the folder that `"$HOME/.agents/bin/onboarding-pack" find` prints.

Do not check for `docs/onboarding/README.md`: the rubric works without a pack. Exit status 1 of `find` means none is
recorded. For any other failure (the folder is gone, the tool is missing), say so in one line and carry on.

When a rubric exists, show it, ask what to change, and never replace it without a yes. A refresh keeps every ID and
every `told by` criterion, and changes only the criteria the engineer names. Show what changed before you save. A
change to a rubric in `AGENTS.md` is not written by this skill: print the revised section for the engineer to paste.

## Flow

1. **Find the rubric.** Do the lookup above. Say what you found, or say "no rubric".
2. **Read the sources.** Read only these, and nothing else: `CONTRIBUTING.md`, the PR template
   (`.github/pull_request_template.md`, `docs/pull_request_template.md`, or a template under `.azuredevops/`),
   `CODEOWNERS`, the lint and format config, the pipeline files, the conventions text in the README, and what the
   engineer pastes: past review comments or team rules. Cite each fact from a file as `path:line`.
3. **Draft the criteria.** Give each criterion an ID (`R1`, `R2`), a Rule, Applies to (a path glob or `all`), a
   Severity (`Block`, `Major` or `Minor`), How to check, and a Source. Apply the rules below. At most 15 criteria.
   Propose each severity; the engineer corrects it. If the sources give no criteria, say so and ask the engineer to
   paste rules. With nobody to answer, print no draft and write nothing.
4. **Correct it with the engineer.** Show the draft before you save anything. The engineer adds, drops or changes
   criteria. A rule the engineer states gets the source `told by <role>`: ask for the role once. That role is the
   file's Owner: ask for it once even when the engineer states no rule. With no role, write
   `Owner: unknown: ask the team`. Ask nothing else about a rule that has a source.
5. **Save it.** Do this only after the engineer agrees. Follow Saving.

## Criteria

- **One rule, one criterion.** When two sources state the same rule, write one criterion and list both sources.
- **Source.** A source is `path:line`, a URL, or `told by <role>`. A criterion with none of these is written
  `inferred:` and its severity is `Minor`. It cannot be higher.
- **Checkable.** Keep a rule only when a reviewer can check from the diff or a command. Drop the rest.
- **Lint.** Drop a style rule that the lint or format check already enforces. Point to the lint command in an optional
  `Lint:` header line, or to its config file when there is no command.
- **Built-in rules win.** The file header says a rubric never lowers the severity of a failing build or test, a
  security problem, data loss or a contract break. A criterion may add a check and raise severity.

## Saving

Write one file. Choose the folder in this order:

- **A pack folder exists:** `docs/onboarding/` when it exists, or the folder that `"$HOME/.agents/bin/onboarding-pack"
  find` prints. Save `review-rubric.md` there.
- **No pack folder:** ask once which agent files the repository may hold: `committed`, `local only` or `none`.
  - `committed`: `docs/onboarding/`.
  - `local only`: `docs/onboarding/`. Print the exact line `docs/onboarding/` for the file that `git rev-parse
    --git-path info/exclude` prints, and tell the engineer to add it. Never add it yourself.
  - `none`: propose the folder that `"$HOME/.agents/bin/onboarding-pack" suggest` prints, or one the engineer names.
    The folder must be an absolute path outside the repository and outside any other working tree. Compare real
    paths (`cd <folder> && pwd -P`), because a link can hide a path inside the repository. An existing empty folder
    is fine. If the path fails, or the folder holds files, ask for another folder, and with nobody to answer write
    nothing. Create the folder
    and save the file there. Do not run `set`: print `"$HOME/.agents/bin/onboarding-pack" set <folder>` for the
    engineer, and say the review skills find the file only after the engineer runs it.
- The `Scanned commit:` line is the output of `git rev-parse HEAD`. In a repository with no commit, write `none yet`.
- A rubric in `AGENTS.md` instead, only when the engineer asks: print it as a `## Review rubric` section for the
  engineer to paste. Keep the criteria as `###` headings. Leave out the `# Review rubric` title and the `Scanned
  commit:` line. Save no file.
- With nobody to answer, or no yes from the engineer, write nothing and print the draft in chat.
- If the file exists, ask before you replace it. Yes rewrites the whole file. No leaves it.

End with one closing line that says where the file is, or that nothing was saved. For `local only`, the same line
tells the engineer to add the exclude line.

## Rules

- One write: the rubric file, and the folder you create for it (`docs/onboarding/` or the `none` folder). Read and
  search only otherwise. No build, no tests, no app, no database.
- Never edit `AGENTS.md`, `CLAUDE.md`, `.gitignore` or `.git/info/exclude`. Print the text for the engineer to paste.
- Name a key, never its value. Keep secrets and any personal name out of the file. Name no customer.
- Write in plain English. One idea per sentence.
- No sub-agents. Do not start another skill.
