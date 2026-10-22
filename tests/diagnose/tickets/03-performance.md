# Ticket 3: the yearly revenue report is slow

Raised by: finance. Environment: test (`data/shop.db`). Command: `python3 -m shop report 2026`.

The yearly revenue report takes several seconds. Finance wants it back in well under one second, and the data
keeps growing.

We think the database needs an index. Please find out why it is slow.
