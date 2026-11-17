import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';
import 'package:inventrix/features/settings/domain/repositories/business_profile_repository.dart';

/// Stores the business identity in the single row of `business_profiles`.
final class DriftBusinessProfileRepository
    implements BusinessProfileRepository {
  /// Creates the repository.
  const DriftBusinessProfileRepository(this._db, this._ids, this._clock);

  final AppDatabase _db;
  final IdGenerator _ids;
  final Clock _clock;

  Future<BusinessProfileRow?> _firstRow() =>
      (_db.select(_db.businessProfiles)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  @override
  Future<Result<BusinessProfile?>> find() => guardDatabase(() async {
    final row = await _firstRow();
    if (row == null || row.name.trim().isEmpty) {
      return null;
    }
    return BusinessProfile(
      name: row.name,
      address: row.address,
      phone: row.phone,
      email: row.email,
      taxId: row.taxId,
      logoPath: row.logoPath,
    );
  });

  @override
  Future<Result<void>> save(BusinessProfile profile) => guardDatabase(
    () => _db.transaction(() async {
      final existing = await _firstRow();
      final now = toEpochMs(_clock.now());
      if (existing == null) {
        await _db
            .into(_db.businessProfiles)
            .insert(
              BusinessProfilesCompanion.insert(
                id: _ids.newId(),
                name: profile.name,
                address: Value(profile.address),
                phone: Value(profile.phone),
                email: Value(profile.email),
                taxId: Value(profile.taxId),
                logoPath: Value(profile.logoPath),
                createdAt: now,
                updatedAt: now,
              ),
            );
        return;
      }
      await (_db.update(
        _db.businessProfiles,
      )..where((t) => t.id.equals(existing.id))).write(
        BusinessProfilesCompanion(
          name: Value(profile.name),
          address: Value(profile.address),
          phone: Value(profile.phone),
          email: Value(profile.email),
          taxId: Value(profile.taxId),
          logoPath: Value(profile.logoPath),
          updatedAt: Value(now),
        ),
      );
    }),
  );
}
