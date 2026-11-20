import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';
import 'package:inventrix/features/product_classification/domain/repositories/product_classification_repository.dart';

/// Drift implementation of [ProductClassificationRepository].
final class DriftProductClassificationRepository
    implements ProductClassificationRepository {
  /// Creates the repository.
  const DriftProductClassificationRepository(this._db);

  final AppDatabase _db;

  ProductClassification _map(ProductClassificationRow r) =>
      ProductClassification(
        id: r.id,
        productId: r.productId,
        system: ClassificationSystem(r.classificationSystem),
        code: r.classificationCode,
        description: r.classificationDescription,
        countryCode: r.countryCode,
        type: ClassificationType.parse(r.classificationType),
        isPrimary: r.isPrimary,
        createdAt: fromEpochMs(r.createdAt),
        updatedAt: fromEpochMs(r.updatedAt),
      );

  ProductClassificationsCompanion _companion(ProductClassification c) =>
      ProductClassificationsCompanion(
        id: Value(c.id),
        productId: Value(c.productId),
        classificationSystem: Value(c.system.code),
        classificationCode: Value(c.code),
        classificationDescription: Value(c.description),
        countryCode: Value(c.countryCode),
        classificationType: Value(c.type.code),
        isPrimary: Value(c.isPrimary),
        createdAt: Value(toEpochMs(c.createdAt)),
        updatedAt: Value(toEpochMs(c.updatedAt)),
      );

  @override
  Future<Result<List<ProductClassification>>> listForProduct(
    String productId,
  ) => guardDatabase(() async {
    final rows =
        await (_db.select(_db.productClassifications)
              ..where((t) => t.productId.equals(productId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.isPrimary),
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return rows.map(_map).toList();
  });

  @override
  Future<Result<ProductClassification?>> getById(String id) =>
      guardDatabase(() async {
        final row = await (_db.select(
          _db.productClassifications,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row == null ? null : _map(row);
      });

  @override
  Future<Result<ProductClassification?>> primaryFor(String productId) =>
      guardDatabase(() async {
        final row =
            await (_db.select(_db.productClassifications)..where(
                  (t) =>
                      t.productId.equals(productId) & t.isPrimary.equals(true),
                ))
                .getSingleOrNull();
        return row == null ? null : _map(row);
      });

  @override
  Future<Result<void>> add(ProductClassification classification) =>
      guardDatabase(
        () => _db.transaction(() async {
          final existing =
              await (_db.select(_db.productClassifications)..where(
                    (t) => t.productId.equals(classification.productId),
                  ))
                  .get();
          final primary = existing.isEmpty || classification.isPrimary;
          if (primary && existing.isNotEmpty) {
            await _demoteAll(classification.productId);
          }
          await _db
              .into(_db.productClassifications)
              .insert(
                _companion(classification.withPrimary(isPrimary: primary)),
              );
        }),
      );

  @override
  Future<Result<void>> update(ProductClassification classification) =>
      guardDatabase(() async {
        final affected =
            await (_db.update(_db.productClassifications)
                  ..where((t) => t.id.equals(classification.id)))
                .write(
                  ProductClassificationsCompanion(
                    classificationSystem: Value(classification.system.code),
                    classificationCode: Value(classification.code),
                    classificationDescription: Value(
                      classification.description,
                    ),
                    countryCode: Value(classification.countryCode),
                    classificationType: Value(classification.type.code),
                    updatedAt: Value(toEpochMs(classification.updatedAt)),
                  ),
                );
        if (affected == 0) {
          throw const FailureException(
            NotFoundFailure('This classification no longer exists.'),
          );
        }
      });

  @override
  Future<Result<void>> remove(String id) => guardDatabase(
    () => _db.transaction(() async {
      final row = await (_db.select(
        _db.productClassifications,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) {
        return;
      }
      await (_db.delete(
        _db.productClassifications,
      )..where((t) => t.id.equals(id))).go();
      if (row.isPrimary) {
        final next =
            await (_db.select(_db.productClassifications)
                  ..where((t) => t.productId.equals(row.productId))
                  ..orderBy([
                    (t) => OrderingTerm.asc(t.createdAt),
                    (t) => OrderingTerm.asc(t.id),
                  ])
                  ..limit(1))
                .getSingleOrNull();
        if (next != null) {
          await (_db.update(
            _db.productClassifications,
          )..where((t) => t.id.equals(next.id))).write(
            const ProductClassificationsCompanion(isPrimary: Value(true)),
          );
        }
      }
    }),
  );

  @override
  Future<Result<void>> setPrimary(String productId, String id) =>
      guardDatabase(
        () => _db.transaction(() async {
          final row =
              await (_db.select(_db.productClassifications)..where(
                    (t) => t.id.equals(id) & t.productId.equals(productId),
                  ))
                  .getSingleOrNull();
          if (row == null) {
            throw const FailureException(
              NotFoundFailure('This classification no longer exists.'),
            );
          }
          await _demoteAll(productId);
          await (_db.update(
            _db.productClassifications,
          )..where((t) => t.id.equals(id))).write(
            const ProductClassificationsCompanion(isPrimary: Value(true)),
          );
        }),
      );

  @override
  Future<Result<List<ClassificationSuggestion>>> search(
    String query, {
    int limit = 20,
  }) => guardDatabase(() async {
    final text = query.trim().toLowerCase();
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final pattern = '%$escaped%';
    final rows = await _db
        .customSelect(
          'SELECT classification_system AS s, classification_code AS c, '
          'MAX(classification_description) AS d, '
          'MAX(classification_type) AS t, '
          'COUNT(DISTINCT product_id) AS n '
          'FROM product_classifications '
          "WHERE (? = '' OR lower(classification_code) LIKE ? ESCAPE '\\' "
          "OR lower(COALESCE(classification_description, '')) LIKE ? "
          "ESCAPE '\\' OR classification_system LIKE ? ESCAPE '\\') "
          'GROUP BY classification_system, classification_code '
          'ORDER BY n DESC, c ASC LIMIT ?',
          variables: [
            Variable.withString(text),
            Variable.withString(pattern),
            Variable.withString(pattern),
            Variable.withString(pattern),
            Variable.withInt(limit),
          ],
          readsFrom: {_db.productClassifications},
        )
        .get();
    return [
      for (final r in rows)
        ClassificationSuggestion(
          system: ClassificationSystem(r.read<String>('s')),
          code: r.read<String>('c'),
          description: r.readNullable<String>('d'),
          type: ClassificationType.parse(r.read<String>('t')),
          productCount: r.read<int>('n'),
        ),
    ];
  });

  Future<void> _demoteAll(String productId) =>
      (_db.update(
        _db.productClassifications,
      )..where((t) => t.productId.equals(productId))).write(
        const ProductClassificationsCompanion(isPrimary: Value(false)),
      );
}
