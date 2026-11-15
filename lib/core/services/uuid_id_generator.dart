import 'package:inventrix/core/services/id_generator.dart';
import 'package:uuid/uuid.dart';

/// [IdGenerator] producing random UUID v4 strings.
final class UuidIdGenerator implements IdGenerator {
  /// Creates a generator.
  UuidIdGenerator() : _uuid = const Uuid();

  final Uuid _uuid;

  @override
  String newId() => _uuid.v4();
}
