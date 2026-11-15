# Roadmap

| Phase | Name | Gate (summary) |
|---|---|---|
| 0 | Analysis & Architecture | docs reviewed/approved |
| 1 | Foundation | app boots, DB + FKs + migration tests, GetIt, GoRouter, themes, Money/Quantity tests, analyze clean |
| 2 | Master data | categories, units, products, customers, suppliers CRUD + tests |
| 3 | Inventory | ledger, adjustments, WAC, reconciliation |
| 4 | Purchases | draft/post/void, WAC, transactional |
| 5 | Sales & billing | stock-safe posting, numbering, PDF/share (code written, partially verified) |
| 6 | Payments | allocations, reversals, derived statuses |
| 7 | Returns | eligibility, restock, settlement |
| 8 | Expenses | CRUD, attachments, reports (code written, partially verified) |
| 9 | Dashboard & reports | queries, charts, export |
| 10 | Backup & restore | verified snapshot, safe restore |
| 11 | Settings | currency, numbering, tax config |
| 12 | QA & release | full test + platform builds |

Each phase ends with the Phase Completion Report; no phase starts before the previous one passes its acceptance criteria.
