import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart' as ft;

/// A minimal stand-in for `bloc_test`'s `blocTest`, so the project does not
/// need the `bloc_test` package (it conflicts with the test packages pinned
/// by the Flutter SDK on some versions).
///
/// Supports the subset the project uses: [setUp], [build], [act], [wait],
/// [skip], [expect] (a list, a matcher or a function returning either) and
/// [verify]. States emitted while [act] runs and during [wait] are collected.
void blocTest<B extends BlocBase<S>, S>(
  String description, {
  required B Function() build,
  FutureOr<void> Function()? setUp,
  FutureOr<void> Function(B bloc)? act,
  Duration? wait,
  int skip = 0,
  Object? Function()? expect,
  FutureOr<void> Function(B bloc)? verify,
}) {
  ft.test(description, () async {
    if (setUp != null) {
      await setUp();
    }
    final bloc = build();
    final states = <S>[];
    final subscription = bloc.stream.listen(states.add);
    try {
      if (act != null) {
        await act(bloc);
      }
      // Let queued events and pending futures finish.
      await Future<void>.delayed(wait ?? Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (expect != null) {
        final expected = expect();
        _expect(states.skip(skip).toList(), expected);
      }
      if (verify != null) {
        await verify(bloc);
      }
    } finally {
      await subscription.cancel();
      await bloc.close();
    }
  });
}

void _expect(Object? actual, Object? expected) => ft.expect(actual, expected);
