# Verify hand-off

Step 9 of `agentd-dev-rev`. Give the engineer what a fresh verify session needs. Do the parts in this order.

- **Marker lookup first.** Look for `verify-*/SKILL.md` under any `.github/skills/` or `.claude/skills/` folder. Then look for `verify-*/SKILL.md` under the folder that `"$HOME/.agents/bin/onboarding-pack" verify-find` prints. It is the repository's own verify folder when its files policy is `none`. Exit status 1 means none is recorded; for any other failure (the folder is gone, the tool is missing), say so in the reply and carry on without it. Accept only a file whose header has `generated-by: agentd-verify-init` nested under `metadata:`. Ignore a `verify-*` skill without that marker. If several marked skills match in one place, list them and ask which one. A marked skill in the repository wins over one outside it; name the other one in the reply. If no marked skill exists in either place, write only this closing line: "No project verify skill. Run `/agentd-verify-init` once, or verify by hand." In that case dev-rev asks no base-branch question and writes no Verify block.
- **No user-visible effect.** Decide this before the base-branch question. Write `Verify: none: <reason>` and no other field, and ask no base-branch question.
- **Base.** Propose the remote's default branch, found with `git symbolic-ref refs/remotes/origin/HEAD`. The engineer confirms it or names another. Send the step 8 report and this question first, and write the block after the answer. Never write a `Base:` the engineer did not confirm. Then run `git merge-base HEAD <branch>`, or `git merge-base HEAD origin/<branch>` when the branch has no local branch, and write `Base: <branch> @ <sha>`. If there is nobody to answer, or the engineer does not know the branch, write `Base: unknown`. If `git merge-base` prints nothing, write `Base: unknown`. Never guess the branch.
- **The block.** Write the block below, with these twelve lines plus the optional `API:` line, and no `Expected:` line. The block says what changed and how to reach it, not what is right.

```
Verify:
Ticket: <number>
Base: <base branch> @ <merge-base sha>
Change: <the user-visible behaviour that changed, 1-2 sentences; navigation, and one source of claims>
Feature: <feature file(s), or <feature> (index only)>; entry points: <which ones>
Neighbours: <features from blast-radius> | none
Data: empty | setup: <recipe names> | bacpac: <what the data must contain> | records: <specific rows to create>
Roles: default | <role list>
API: <the API the run must use, and "debug token" when the engineer will run the API call with a debug token and paste back the value>
Steps: <numbered user actions>
Side effects: <tables or rows to check with a read-only SELECT> | none
Diagnose: <from the diagnose hand-off, verbatim: the Confidence line, the Root cause line, and the reproduction command from the Verification line (not its expected output)> | none
Reference anchors: <calculation reference anchors, as an index only> | none
```

- **API.** The `API:` line is the only line that may be left out. Write it only when the engineer names the API the run must use, for example which backend an iOS app calls. Add `debug token` only when the engineer says they will run the API call themselves. Otherwise leave the line out, and do not write `API: default`; the verifier then uses the default API of the stack reference.
- **Diagnose.** If the engineer pasted a diagnose hand-off, copy its Confidence line, its Root cause line and the reproduction command from its Verification line verbatim. Leave out the expected output. In a hand-off written as Markdown sections, the Root cause line is the text under `## Root cause`, joined into one line: keep the words and the `path:line` references, drop the `- ` bullet marks, and leave out any fenced block. The reproduction command is the command in step 1 under `## Verification`. With no hand-off, write `Diagnose: none`.
- **Neighbours and Feature.** Read the paths under `Risks to cover` in a pasted `agentd-blast-radius` add-on block. Map each path to the features whose `Code folders` column in the marked skill's `features/README.md` holds a folder that contains it. Write those features as `Neighbours:`. With an add-on block, take `Feature:` from the same list. With no add-on block, write `Neighbours: none`, ask the engineer which feature to drive, and write the answer as `Feature:`. With no `Code folders` column in the map, write `Neighbours: none`, say that the map has no `Code folders` column, and ask the engineer which feature to drive. Ask this in the same message as the base-branch question. Whenever `Feature:` or `Neighbours:` names a feature whose File column says `none yet`, from either list or from the engineer, write it as `<feature> (index only)`. On the `Feature:` line, give its Route or screen column as its entry point.
- **Closing line.** End with: "Run `/verify-<app>` in a fresh session, and paste the raw ticket and the Verify block", using the real skill name. When the marked skill is outside the repository and neither `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/verify-<app>` nor `~/.agents/skills/verify-<app>` exists, the command does not load: say the engineer can load the skill from its path (`verify-<app>/SKILL.md` in the folder `verify-find` printed) or run `/agentd-verify-init` to get the links.
- A failed verification returns to `/agentd-dev-rev` as a new task, with its own review rounds.
- dev-rev never launches the app.
