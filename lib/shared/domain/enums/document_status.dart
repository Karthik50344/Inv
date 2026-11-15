/// Lifecycle status shared by every business document (purchases, sales,
/// returns, ...). [dbName] is the stored value.
///
/// Only [posted] documents affect inventory and financial records. Posted
/// documents are never edited or deleted: they are reversed ([voided]).
/// Payment status is a separate, derived concept (Phase 6).
enum DocumentStatus {
  draft('draft', 'Draft'),
  created('created', 'Created'),
  pendingApproval('pendingApproval', 'Pending approval'),
  approved('approved', 'Approved'),
  authorized('authorized', 'Authorized'),
  posted('posted', 'Posted'),
  cancelled('cancelled', 'Cancelled'),
  voided('voided', 'Voided');

  const DocumentStatus(this.dbName, this.label);

  /// Value stored in the database.
  final String dbName;

  /// Label for the UI.
  final String label;

  /// Allowed transitions. `approved -> posted` skips authorization, which
  /// is optional; approval itself is a configurable step.
  static const Map<DocumentStatus, Set<DocumentStatus>> _transitions = {
    draft: {pendingApproval, posted, cancelled},
    created: {pendingApproval, posted, cancelled},
    pendingApproval: {approved, draft, cancelled},
    approved: {authorized, posted, cancelled},
    authorized: {posted, cancelled},
    posted: {voided},
    cancelled: {},
    voided: {},
  };

  /// Parses a stored value.
  static DocumentStatus fromDbName(String value) =>
      DocumentStatus.values.firstWhere(
        (status) => status.dbName == value,
        orElse: () => throw ArgumentError.value(
          value,
          'value',
          'Unknown document status',
        ),
      );

  /// Whether a document in this status may move to [next].
  bool canTransitionTo(DocumentStatus next) =>
      _transitions[this]!.contains(next);

  /// Whether the document content may still be edited.
  bool get isEditable => this == draft;

  /// Whether the document has taken effect on inventory and financials
  /// (posted, and not reversed).
  bool get isPosted => this == posted;

  /// Whether the document is finished: no further transition is possible.
  bool get isFinal => _transitions[this]!.isEmpty;
}
