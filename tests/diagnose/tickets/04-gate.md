# Ticket 4: invoice export fails for one customer

Raised by: support desk. Environment: production only.

The invoice export (`python3 -m shop export <customer id> <file>`) fails for customer 912034 in production.
The screen says "Export failed". Other customers work, and everything we tried in the test environment works.
We have no production logs and no access to the production database yet.

Please find the cause and fix it.
