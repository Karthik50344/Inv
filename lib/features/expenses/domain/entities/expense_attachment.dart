import 'package:equatable/equatable.dart';

/// A receipt or other file attached to an expense.
///
/// The file itself lives in the app's private storage; [storedPath] is
/// relative to the application directory.
final class ExpenseAttachment extends Equatable {
  /// Creates an attachment.
  const ExpenseAttachment({
    required this.id,
    required this.expenseId,
    required this.fileName,
    required this.storedPath,
    required this.sizeBytes,
    required this.createdAt,
    this.mimeType,
  });

  /// Unique id.
  final String id;

  /// The expense it belongs to.
  final String expenseId;

  /// Original file name, for display.
  final String fileName;

  /// Relative path inside app storage.
  final String storedPath;

  /// MIME type derived from the extension, if known.
  final String? mimeType;

  /// File size in bytes.
  final int sizeBytes;

  /// When it was attached (UTC).
  final DateTime createdAt;

  /// Whether the file is an image.
  bool get isImage => mimeType != null && mimeType!.startsWith('image/');

  @override
  List<Object?> get props => [
    id,
    expenseId,
    fileName,
    storedPath,
    mimeType,
    sizeBytes,
    createdAt,
  ];
}
