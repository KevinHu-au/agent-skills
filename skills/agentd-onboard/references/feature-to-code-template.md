# <Project name> feature to code

> Template for `docs/onboarding/feature-to-code.md`. Always write this file, so the pack has the same layout for every project. Keep the header lines and the block format exactly. A refresh and the checks read them. Replace every `<...>`. Delete every guidance line that starts with `>`.
>
> Budget: about 1,100 words for the file, and at most about 220 words for each use case. One block for each main use case, named as in `README.md`. Rows are keyed by use case, not by screen, because one screen can serve several features and one feature can span several screens.
>
> Use the layer names from `## Start here` in `README.md`. A cell is `none`, `unknown:` and who to ask, `inferred:` and a note, or a backticked value. Put one value in each backtick pair, so a checker can read it.
>
> In the "Data loads in" and "Calculations and rules in" columns, a value is a path in the form `path`, `path:N` or `path:N-M`. In the two path columns, backtick only the path; write any note without backticks. In a "Search terms" table, the "Business term" column is plain text: the words a user uses. The backticked cells in the layer columns are exact search strings, never paths. Check each string with a search before you write it. The `Sources:` line lists every path the block cites. The checker accepts a path that exists on disk even when git ignores it, but it finds a search term only in files that git tracks or could track, so a term that appears only in an ignored file is a miss.
>
> A procedure or query with no caller found is written `inferred: no caller found`. Where one value is calculated in more than one layer, say which layer owns it. When the project has no user-facing use cases (a library, say), write only the scan lines and one line: `unknown: no user-facing use cases found`, and who to ask.
>
> Markers: `unknown:` not found, and who to ask. `inferred:` worked out, not confirmed. `changed:` updated in the last refresh. `conflict:` two sources disagree, and the code wins. Never write a secret value. Name the key only.

Scanned commit: <the full output of git rev-parse HEAD>
Scanned on: <YYYY-MM-DD>

## <Use case name, as in README.md>

| Layer | Data loads in | Calculations and rules in |
|---|---|---|
| <layer> | `<path:line>` | `<path:line>` or none |
| <layer> | `<path:line>` | inferred: no caller found |

Owner of the calculation: <layer>, or none when one layer calculates it.

### Search terms

| Business term | <layer> | <layer> |
|---|---|---|
| <words the user uses, for example Shipping date> | `<exact search string, for example shp_dt>` | `<exact search string>` |

Sources: <path:line, path:line>
