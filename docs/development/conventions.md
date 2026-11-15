# Conventions

- Files `snake_case.dart`; one public class per file where practical; classes `UpperCamelCase`.
- Entities: `Product`; DB rows: `ProductRow` (Drift); DTO/models: `ProductModel`; mappers: `ProductMapper`.
- Use cases: verb phrase, `PostSalesInvoice`, with a single `call` method returning `Future<Result<T>>`; no pass-through use cases that add nothing.
- BLoC: `XBloc/XEvent/XState`; states immutable (Equatable; Freezed only for large unions); Cubit for simple state.
- Repositories: contract `ProductRepository` in domain, impl `DriftProductRepository` in data.
- Tables: plural snake_case; columns snake_case with `_minor`, `_bp`, `_milli` suffixes.
- No `double` for money/quantity. No `print`; use `logging`. Time always UTC in storage, local only in presentation.
- Lints: `very_good_analysis`; generated files excluded from analysis.
- Tests mirror `lib/` paths and end in `_test.dart`.
