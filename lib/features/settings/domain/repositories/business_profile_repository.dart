import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';

/// Persistence contract for the business identity.
abstract interface class BusinessProfileRepository {
  /// The saved profile, or `null` while the owner has not entered one.
  Future<Result<BusinessProfile?>> find();

  /// Saves [profile], replacing the previous one.
  Future<Result<void>> save(BusinessProfile profile);
}
