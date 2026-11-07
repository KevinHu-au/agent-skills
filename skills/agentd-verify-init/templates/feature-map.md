# Feature map template

Used in Flow step 4 of `agentd-verify-init`. It gives the shape of three files in the verify skill's `features/` folder:
`README.md`, one file per feature, and `data-setup.md`. The map holds user steps only: routes, labels and steps. It has
no customer values, so the separate verifier can use it without the developer's reasoning. Examples use placeholders.
Replace each `<placeholder>`.

## features/README.md

The file starts with the two scan lines. Update mode takes `Scanned commit` from them and lists the changed code with
`git diff --name-only <commit>`. Set `Scanned commit` to the full output of `git rev-parse HEAD` and `Scanned on` to
today.

```
Scanned commit: <full sha>
Scanned on: <date>

# Feature map

Entry feature: <feature-a>

| Feature | File | Route or screen | Code folders | Why it is here |
|---|---|---|---|---|
| <feature-a> | <feature-a>.md | <route or screen> | <folder>, <folder> | entry feature: opens or creates the main record |
| <feature-b> | <feature-b>.md | <route or screen> | <folder> | <churn count, calculation, or permission rule> |
| <feature-c> | none yet | <route or screen> | <folder> | index only: <what a user does there> |

Setup recipes: data-setup.md
```

The index has a row for every feature a user can reach. A row whose File column says `none yet` is index only: it has
no feature file until update mode writes one. Route or screen is the route of a web app or the screen name of a mobile
app. Code folders are repository paths relative to the repository root, not customer values. `agentd-dev-rev` reads them to map a blast-radius path to a
feature.

## One feature file

A `Needs:` line under the title names the setup recipes the feature needs. The verify skill runs them when the
engineer chooses the feature. Then four sections, in this order. Mark a step built only from general knowledge of the platform `inferred:`. Mark a step
nobody could check `unknown:`.

```
# <feature-a>

Needs: <recipe names from data-setup.md> | none

## Sub-features
- <sub-feature>: <what a user can do, in one line>

## How to get to it
1. <menu or route>, then <label of the control>
2. <what the user sees when it worked>

## Driving it
1. <user action, by visible label or role>
2. <user action>
Save a screenshot after each step. Note the API call each step makes (from the network log).

## Gotchas
- <a wait, a fixed port, a field that clears itself, a control with no label>
```

## data-setup.md

Named recipes. The Verify block's `Data:` line names them. `state.json` records which recipes ran on a container, so a
later run on the same container skips them. A recipe creates data through the user interface as admin. Write steps and
labels only, with no customer values: no real names, numbers or file contents. Name a test file by its folder, not by
its content.

```
# Setup recipes

## <recipe-basic>
Needs: <empty schema | another recipe>
Order: <recipes this one must follow when they also run, and why> (optional)
1. <user action>
Result: <what exists afterwards, in words>

## <recipe-locked-period>
Needs: <recipe-basic>
1. <user action>
Result: <what exists afterwards, in words>
```
