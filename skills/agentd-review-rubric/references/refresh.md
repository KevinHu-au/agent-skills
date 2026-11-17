# Refresh

For a run that finds an existing rubric. The rubric belongs to the team. Never replace it without a yes. Change only
what the engineer names or the chosen fix covers.

## Gaps

In Flow step 1, after you show the rubric, list its gaps by criterion ID:

- a criterion with no `Applies to` line;
- a criterion with no Severity line. A heading that ends in `(Block)`, `(Major)` or `(Minor)` still counts as missing;
- a criterion with no Source line. Readers count it as `inferred:`, and so as Minor, whatever its severity.

A missing `### Risk tiers` section is not a gap. The section is optional.

## Choices

Then ask which change to make. Offer these four, in this order:

1. **Fix the gaps only.** Add each missing line, and change no line that exists.
   - Applies to: propose a glob from the paths the rule names, or `all`.
   - Source: ask the engineer for the role that set the rule, and write `told by <role>`. With no answer, write
     `inferred: <where the rule came from>`.
   - Severity: take it from a heading that ends in `(Block)`, `(Major)` or `(Minor)`, or else propose one. When the
     Source is `inferred:`, write `Minor`, and name the heading severity in the draft so the engineer can give a role.
2. **Specific edits.** Change only the criteria or rows the engineer names. A named `told by` criterion or row may
   change too.
3. **Full refresh.** Run the whole Flow and propose new criteria. Change an existing criterion only when the engineer
   names it.
4. **Nothing.** Write nothing, and end.

With any choice but Nothing, also ask whether a path needs a higher tier than the built-in signals of `risk-tiers.md`
give it. Draft `### Risk tiers` rows only when the engineer says yes.

## What the Flow does

- Flow step 2 reads only the sources the choice needs, from its list. Fix the gaps only reads none: its globs come
  from the paths the rules name. A Risk tiers question reads the Risk areas and `CODEOWNERS`.
- Flow step 3 drafts only what the choice covers. Only Full refresh adds criteria.
- Flow step 4 asks for the Owner only when the header has no `Owner:` line.
- Flow step 5 saves to the place where the rubric was found, never to a new place. A rubric in `AGENTS.md` is printed
  for the engineer to paste, as Saving says.

## What a refresh keeps

- Every ID. A dropped criterion keeps its number.
- Every criterion and Risk tiers row that the engineer does not name, including every `told by` one.
- Every section the template does not have, such as a reviewer contract, unchanged and in place.
- The header of a rubric file. Fix the gaps only and Specific edits change only `Date:`, and leave `Scanned commit:`
  as it is. Full refresh sets `Scanned commit:` to `git rev-parse HEAD`. A rubric in `AGENTS.md` has no header
  lines: add none.

Show what changed before you save.
