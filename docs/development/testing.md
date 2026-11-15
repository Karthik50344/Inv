# Testing Strategy

| Level | Tools | Focus |
|---|---|---|
| Domain unit | flutter_test | value objects, rounding, tax, WAC, status transitions, use cases (mocktail fakes) |
| Data | Drift in-memory DB | queries, constraints (FKs, CHECK, unique, ledger immutability triggers), mappers |
| Migration | `SchemaVerifier` | each version step with seeded data |
| BLoC | bloc_test | initial/loading/success/empty/validation/db failure/unexpected |
| Widget | flutter_test | rendering, form validation, navigation, empty/error states |
| Integration | integration_test | purchase → sale → payment → return → backup → restore flow |

Mandatory edge cases: zero/fractional qty, large amounts, rounding, discounts, tax-inclusive/exclusive, partial payments, reversals, returns, insufficient stock, WAC residual rounding, duplicate posting, rollback on mid-transaction failure.
Rule: a command is reported as passing only if actually executed and its output seen.
