// Verifies the Clean Architecture dependency rules.
//
// Run from the project root: `dart run tool/check_imports.dart`.
import 'dart:io';

const _frameworkPackages = [
  'flutter',
  'flutter_bloc',
  'drift',
  'drift_flutter',
  'sqlite3',
  'get_it',
  'go_router',
  'path_provider',
  'share_plus',
  'file_picker',
  'printing',
  'pdf',
];

final RegExp _importPattern = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
);

/// Returns human readable rule violations for every Dart file below [lib].
List<String> findViolations(Directory lib) {
  final violations = <String>[];
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (entity.path.endsWith('.g.dart') ||
        entity.path.endsWith('.freezed.dart')) {
      continue;
    }
    final path = entity.path.replaceAll(r'\', '/');
    final isDomain = path.contains('/domain/');
    final isPurePart =
        isDomain ||
        path.contains('/lib/core/errors/') ||
        path.contains('/lib/core/result/') ||
        path.contains('/lib/core/utils/') ||
        path.contains('/lib/core/services/');
    final isPresentation =
        path.contains('/presentation/') ||
        path.contains('/lib/app/shell/') ||
        path.contains('/lib/app/router/');

    for (final line in entity.readAsLinesSync()) {
      final match = _importPattern.firstMatch(line);
      if (match == null) {
        continue;
      }
      final uri = match.group(1)!;
      if (isPurePart && _isFramework(uri)) {
        violations.add('$path imports framework package: $uri');
      }
      if (isDomain && _isLayer(uri, 'data')) {
        violations.add('$path (domain) imports data layer: $uri');
      }
      if (isDomain && _isLayer(uri, 'presentation')) {
        violations.add('$path (domain) imports presentation layer: $uri');
      }
      if (isPresentation && (_isLayer(uri, 'data') || _isDatabase(uri))) {
        violations.add('$path (presentation) imports data/database: $uri');
      }
    }
  }
  return violations;
}

bool _isFramework(String uri) => _frameworkPackages.any(
  (name) => uri.startsWith('package:$name/') || uri == 'dart:ui',
);

bool _isLayer(String uri, String layer) =>
    uri.startsWith('package:inventrix/') && uri.contains('/$layer/');

bool _isDatabase(String uri) =>
    uri.startsWith('package:inventrix/core/database/') ||
    uri.startsWith('package:drift/') ||
    uri.startsWith('package:sqlite3/');

void main() {
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('Run this from the project root (lib/ not found).');
    exit(2);
  }
  final violations = findViolations(lib);
  if (violations.isEmpty) {
    stdout.writeln('Dependency rules OK.');
    return;
  }
  violations.forEach(stderr.writeln);
  exit(1);
}
