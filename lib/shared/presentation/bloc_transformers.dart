import 'package:bloc/bloc.dart';

/// Processes events strictly one after another (no overlapping handlers),
/// which keeps rapid search/filter changes in order.
EventTransformer<E> sequentialTransformer<E>() =>
    (events, mapper) => events.asyncExpand(mapper);
