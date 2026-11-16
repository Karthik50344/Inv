import 'package:equatable/equatable.dart';

/// A one-time message about a restore that finished while the app was being
/// restarted, shown after the app is back.
final class RestoreNotice extends Equatable {
  /// Creates a notice.
  const RestoreNotice({required this.succeeded, required this.message});

  /// Whether the restored data is now live.
  final bool succeeded;

  /// User-facing text.
  final String message;

  @override
  List<Object?> get props => [succeeded, message];
}
