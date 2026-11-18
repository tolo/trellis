import 'dart:convert';

import 'checks.dart';

/// Manual results can carry any recorded outcome, including unrun checks.
bool validManualResult(Object? result) => switch (result) {
  {'status': 'pass' || 'fail' || 'not-run' || 'release-prep', 'evidence': final List<Object?> evidence} =>
    evidence.every((entry) => entry is String),
  _ => false,
};

/// Folds one automated item according to the gate's browser fallback decision.
String gateItemStatus(Iterable<GateResult> results) {
  if (results.any((result) => result.status == 'fail')) return 'fail';
  if (results.any((result) => result.status == 'not-run' && !result.unsupported) ||
      !results.any((result) => result.status == 'pass')) {
    return 'not-run';
  }
  return 'pass';
}

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
    items[item] = {
      'status': gateItemStatus(results.values),
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
