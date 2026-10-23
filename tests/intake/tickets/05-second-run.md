# Work item: discounts on the invoice file

Raised by: finance team, through the support desk.

Finance can't see discounts on invoices. When an invoice total is lower than the price list, they have to ask us
why.

Please copy each coupon's amount from the coupon setup into a new "discount" column in the invoice file.

---

## Comment from the support team (earlier intake run)

### Our understanding
Finance cannot see why an invoice total is below the price list, so they have to ask the support desk. They want
the invoice file to show the discount on each invoice.

### Questions
1. Does finance read the invoice file by column name or by column position? May we add a new column at the end?
   Why it matters: finance's import may break if the file changes. Our default: none, we need your answer.
2. Should the discount column show the amount taken off, the coupon code, or both?
   Why it matters: it decides what the column holds. Our default: the amount taken off.
3. Is one discount per order enough?
   Why it matters: the file has one row per order. Our default: one discount per order.
4. Do you need invoice files you already received to be sent again with the new column?
   Why it matters: it decides whether we resend old files. Our default: no. The next file you receive lists all of
   the account's orders with the new column.

### Next
Once you answer, we will write up the change.

---

## Reply from the finance team

Finance reads columns by name, so a new last column is fine. Discount means the amount the coupon took off the
order, per order, in dollars.
