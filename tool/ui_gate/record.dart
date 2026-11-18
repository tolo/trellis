import 'dart:convert';

import 'checks.dart';

/// Manual results can carry any recorded outcome, including unrun checks.
bool validManualResult(Object? result) => switch (result) {
  {'status': 'pass' || 'fail' || 'not-run' || 'release-prep', 'evidence': final List<Object?> evidence} =>
    evidence.every((entry) => entry is String),
  _ => false,
};

/// Folds browser results without changing any human-entered manual item.
Map<String, Object?> gateRecord(
  String name,
  Map<String, Map<String, GateResult>> runs, {
  Map<String, Object?>? previous,
}) {
  final items = <String, Object?>{};
  for (final item in automatedItems) {
    final results = {
      for (final run in runs.entries) run.key: run.value[item] ?? const GateResult('not-run', ['item did not run']),
    };
    final status = results.values.any((r) => r.status == 'fail')
        ? 'fail'
        : results.values.any((r) => r.status == 'not-run' && !r.unsupported) ||
              !results.values.any((r) => r.status == 'pass')
        ? 'not-run'
        : 'pass';
    items[item] = {
      'status': status,
      'browsers': {for (final entry in results.entries) entry.key: entry.value.toJson()},
    };
  }
  final existing = (previous?['items'] as Map?) ?? const {};
  for (final item in manualItems) {
    items[item] = existing[item] ?? {'status': 'release-prep', 'evidence': <String>[]};
  }
  return {
    'component': name,
    'automated': items.values.take(automatedItems.length).every((raw) => (raw as Map)['status'] == 'pass')
        ? 'pass'
        : 'fail',
    'items': items,
  };
}

String encodeRecord(Map<String, Object?> record) => '${const JsonEncoder.withIndent('  ').convert(record)}\n';
