import 'package:equatable/equatable.dart';

/// Whether a classification code describes goods or services.
enum ClassificationType {
  /// Goods.
  goods('goods', 'Goods'),

  /// Services.
  services('services', 'Services'),

  /// Anything else.
  other('other', 'Other');

  const ClassificationType(this.code, this.label);

  /// Stable storage code.
  final String code;

  /// Name shown to users.
  final String label;

  /// The type stored as [code]; unknown codes become [other].
  static ClassificationType parse(String code) {
    for (final value in values) {
      if (value.code == code) {
        return value;
      }
    }
    return other;
  }
}

/// An open-ended classification system (HSN, SAC, HS, any custom one).
final class ClassificationSystem extends Equatable {
  /// Creates a system from its stable lowercase [code].
  const ClassificationSystem(this.code);

  /// Indian HSN (goods).
  static const ClassificationSystem hsn = ClassificationSystem('hsn');

  /// Indian SAC (services).
  static const ClassificationSystem sac = ClassificationSystem('sac');

  /// International Harmonized System.
  static const ClassificationSystem hs = ClassificationSystem('hs');

  /// Stable storage code.
  final String code;

  /// Whether this is one of the three built-in numeric systems.
  bool get isBuiltIn => this == hsn || this == sac || this == hs;

  /// Name shown to users (`HSN`, `SAC`, `HS`, or the custom code).
  String get displayName => code.toUpperCase();

  @override
  List<Object?> get props => [code];
}

/// One classification code of a product.
final class ProductClassification extends Equatable {
  /// Creates a classification.
  const ProductClassification({
    required this.id,
    required this.productId,
    required this.system,
    required this.code,
    required this.type,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.countryCode,
  });

  /// Identifier.
  final String id;

  /// The product.
  final String productId;

  /// The system the code belongs to.
  final ClassificationSystem system;

  /// The code as normalised by `ClassificationValidator`.
  final String code;

  /// Free description of the code (optional).
  final String? description;

  /// ISO country the code applies to (optional).
  final String? countryCode;

  /// Goods or services.
  final ClassificationType type;

  /// Whether this is the code printed on documents.
  final bool isPrimary;

  /// Creation time.
  final DateTime createdAt;

  /// Last change time.
  final DateTime updatedAt;

  /// This classification with another primary flag.
  ProductClassification withPrimary({required bool isPrimary}) =>
      ProductClassification(
        id: id,
        productId: productId,
        system: system,
        code: code,
        description: description,
        countryCode: countryCode,
        type: type,
        isPrimary: isPrimary,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  List<Object?> get props => [
    id,
    productId,
    system,
    code,
    description,
    countryCode,
    type,
    isPrimary,
    createdAt,
    updatedAt,
  ];
}

/// A code already used on some product, offered when searching offline.
final class ClassificationSuggestion extends Equatable {
  /// Creates a suggestion.
  const ClassificationSuggestion({
    required this.system,
    required this.code,
    required this.type,
    required this.productCount,
    this.description,
  });

  /// System of the code.
  final ClassificationSystem system;

  /// The code.
  final String code;

  /// Description used with it, if any.
  final String? description;

  /// Goods or services.
  final ClassificationType type;

  /// How many products use it.
  final int productCount;

  @override
  List<Object?> get props => [system, code, description, type, productCount];
}

/// The classification frozen onto a document line.
final class ClassificationSnapshot extends Equatable {
  /// Creates a snapshot.
  const ClassificationSnapshot({
    required this.system,
    required this.code,
    this.description,
  });

  /// System, for example `hsn`.
  final String system;

  /// The code.
  final String code;

  /// Description at the time, if any.
  final String? description;

  /// Short label such as `HSN 8471`.
  String get label => '${system.toUpperCase()} $code';

  @override
  List<Object?> get props => [system, code, description];
}
