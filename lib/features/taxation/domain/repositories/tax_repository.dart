import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_context.dart';

/// Read access to the tax configuration.
///
/// Editing (regimes, rules, components, ...) is added with the tax settings
/// screens; the engine only needs this snapshot.
abstract interface class TaxRepository {
  /// Loads the whole configuration into memory.
  Future<Result<TaxConfiguration>> loadConfiguration();

  /// The default profile and seller location, or `null` when no default
  /// tax profile exists (documents then use the legacy single-rate path).
  Future<Result<TaxContext?>> loadContext();
}
