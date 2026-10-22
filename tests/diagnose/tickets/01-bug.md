# Ticket 1: invoice total is wrong with a coupon

Raised by: support desk. Environment: test (`data/shop.db`).

Order 90001 (customer 1) uses the coupon SAVE5. The invoice shows a total of 30.00. The customer says it
should be 35.00, because SAVE5 takes 5.00 off the order.

We think the SAVE5 coupon is set up wrongly in the database, maybe as 10.00 instead of 5.00. Please check
the coupon data and fix it.
