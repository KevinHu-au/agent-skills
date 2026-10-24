# Answer template

Two shapes for the chat, one for a vague question, and one for an export file. Keep an answer to about one screen.
Use the bold labels as written, in this order. Leave out a label only where this file says it is optional. The
examples use a made-up shop, not a real project.

## Answer

For `figure or term`, `status` and `code` questions.
Line budget, 60 lines in all as the target, 70 at most: Short answer 3, Domain 3, Core code 6, Flow 18 (layers plus
the formula and its inputs, or the Conditions), Traps 5, Gaps 3, Ask next 4, Next 1. The labels and blank lines make
up the rest. In the Flow, name the screen once: route, tab, column and grid are one screen line, not four. Leave out
pure plumbing such as a mapping step that copies a value unchanged.

- **Short answer**: two or three sentences in business words. What it is and why it matters to the user.
- **Domain**: the general meaning, marked `general knowledge` when it is an industry term, then what this project means
  by it. Say where the two differ.
- **Core code**: the data model (entity or class, `path:line`); where the calculation lives (service, handler, stored
  procedure, `path:line`); the schema (table, columns, and the migration script that made them).
  A figure computed in the frontend points at that code, and the flow still goes to the data source of its inputs.
- **Flow**: one layer per line, in order, each line starting with a plain text arrow (`→`), holding at most one
  `path:line`, and at most 120 characters: `→ <layer>: <name>, <path:line>`. A layer the stack does not have is
  `none`. A layer that should exist but was not found is `unknown:` with who to ask. A hop you cannot trace (dependency
  injection, reflection, an event, a queue) is `inferred:` on its own flow line, naming the missing hop, with the
  `path:line` of the last place you could trace: `→ inferred: <hop> (no registration found for <type>), <path:line>`.
  - For a computed value, add the formula, then one line per input: what it is and where it comes from.
  - For a status, add `Conditions:`, one line per code path that sets it: the condition, `path:line`,
    and what moves it out.
- **Traps**: easily confused points, one line each. For a figure, the first trap says what it is not, for example a
  budget figure that is not actual spend, a computed figure that is not stored, or a forecast that is not approved.
  Leave out the label when there are none.
- **Gaps**: the `conflict:`, `unknown:` and `inferred:` items that change the answer, one line each. This is not a code
  review: leave out bugs that do not bear on the question. Leave out the label when there are none.
- **Ask next**: two to four drill-down topics found while tracing, as short questions.
- **Next**: optional. The plain line `Next: /agentd-diagnose`, with no bold label, and only when the question is about
  a live problem.

Example:

```
**Short answer**
Invoice discount is the amount a coupon takes off an order. Finance uses it to explain why an invoice is below list
price.

**Domain**
general knowledge: a discount is a price reduction shown against the list price.
This project: one discount per order, worked out when the invoice is built, never stored.

**Core code**
Data model: Coupon, shop/models.py:12. Calculation: order_discount, shop/pricing.py:20.
Schema: table coupons (code, percent, amount), migrations/003_coupons.sql:4.

**Flow**
→ page: InvoicePage, web/pages/invoice.tsx:30
→ hook: useInvoice, web/hooks/useInvoice.ts:8
→ service: invoiceService.get, web/services/invoice.ts:14
→ endpoint: GET /invoices/{id}, api/invoices.py:22
→ handler: none (the endpoint calls pricing directly)
→ calculation: order_discount, shop/pricing.py:20
→ inferred: pricing rules loaded through a plugin registry (no registration found for PricingRule), shop/pricing.py:9
→ table: coupons, migrations/003_coupons.sql:4
Formula: discount = min(amount, list total × percent), shop/pricing.py:21
- amount: coupons.amount, fixed coupons only, migrations/003_coupons.sql:6
- percent: coupons.percent, percent coupons only, migrations/003_coupons.sql:5

**Traps**
- The discount is computed, not stored. A changed coupon changes old invoices too (shop/pricing.py:20).

**Gaps**
- conflict: the user guide says one coupon per line; the code applies one per order (shop/pricing.py:20).

**Ask next**
- How is the list total built?
- Who can change a coupon?
```

## Domain overview

For a `domain` question. No layer-by-layer flow: a follow-up on one figure or status uses the Answer shape.
Line budget, 70 lines in all: Short answer 3, Entity map 12, Statuses 6, When created 6, Key formulas 6, Traps 5,
Gaps 3, Ask next 4. The labels and blank lines make up the rest. Each line is at most 120 characters. A domain with
more than that keeps the main entities and figures here and lists the rest under Ask next. One `path:line` per entity
is enough.

- **Short answer**: two or three sentences on what the domain is for, in business words.
- **Entity map**: the main entities and how they relate, as a small text tree, each with `path:line`.
- **Statuses**: the statuses and what moves an entity between them, with `path:line`. Leave out the label when the
  domain has none.
- **When created**: which user action or job writes which rows, with `path:line`.
- **Key formulas**: the main figures, each with its source `path:line`. Name the inputs; do not expand them.
- **Traps**: easily confused points.
- **Gaps**: `conflict:`, `unknown:` and `inferred:` items.
- **Ask next**: two to four single-trail questions that lead into the Answer shape.

## Vague question

When a question could mean several things, search briefly, then list at most five matches, grouped by calculation.
Say how many more there are, then ask:

```
"discount" appears in three places:
1. Invoice discount, per order (shop/pricing.py:20)
2. Line discount on the price list (shop/prices.py:41)
3. Loyalty discount on the account (shop/accounts.py:88)
Which one?
```

With nobody to answer, show the list and stop. Give no answer.

## Export file

Written only when the engineer asks. Like the chat, it is in English. The file starts with these lines:

```
Question: <the first question, in English; translated if the engineer asked in another language>
Commit: <output of git rev-parse HEAD>
Date: <YYYY-MM-DD>
```

Then the Answer or Domain overview shape, with a **Follow-ups** label at the end that holds each follow-up question
and its answer. The file merges all follow-ups on the topic from this chat. A small Mermaid block may replace the
plain text arrows of the flow.
