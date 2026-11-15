/// Converts [value] to UTC epoch milliseconds (the storage format).
int toEpochMs(DateTime value) => value.toUtc().millisecondsSinceEpoch;

/// Converts stored UTC epoch milliseconds back to a UTC [DateTime].
DateTime fromEpochMs(int value) =>
    DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

/// Nullable variant of [toEpochMs].
int? toEpochMsOrNull(DateTime? value) =>
    value == null ? null : toEpochMs(value);

/// Nullable variant of [fromEpochMs].
DateTime? fromEpochMsOrNull(int? value) =>
    value == null ? null : fromEpochMs(value);
