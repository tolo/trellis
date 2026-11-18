import 'dart:convert';

import 'checks.dart';

const gateBrowsers = ['chrome', 'firefox'];
const _items = {...automatedItems, ...manualItems};

/// Manual results can carry any recorded outcome, including unrun checks.
bool _validManualResult(Object? result) => switch (result) {
  {'status': 'pass' || 'fail' || 'not-run' || 'release-prep', 'evidence': final List<Object?> evidence} =>
    evidence.every((entry) => entry is String),
  _ => false,
};

/// Folds one automated item according to the gate's browser fallback decision.
String _gateItemStatus(Iterable<GateResult> results) {
  if (results.any((result) => result.status == 'fail')) return 'fail';
  if (results.any((result) => result.status == 'not-run' && !_unsupportedEmulation(result)) ||
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
      'status': _gateItemStatus(results.values),
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

/// Observed qualification and release evidence from a complete two-browser record.
final class GateRecordAssessment {
  GateRecordAssessment._({
    required this.name,
    this.declaredVerdict,
    this.automated = const {},
    this.manual = const {},
    this.invalid = const [],
    this.unavailable = const [],
  });

  factory GateRecordAssessment.inspect(String name, Object? record) {
    if (record
        case {'component': final component, 'automated': final String verdict, 'items': Map<String, Object?> items}
        when component == name &&
            {'pass', 'fail'}.contains(verdict) &&
            items.length == _items.length &&
            items.keys.toSet().containsAll(_items)) {
      final invalid = <String>[];
      final unavailable = <String>[];
      final manual = <String, String>{};
      final automated = <String, ({String status, Map<String, GateResult> browsers})>{};

      for (final item in manualItems) {
        final value = items[item];
        if (!_validManualResult(value)) {
          invalid.add('$name: $item invalid manual result');
          continue;
        }
        final result = value as Map<String, Object?>;
        final status = result['status']! as String;
        manual[item] = status;
        if (status == 'fail' && !_hasEvidence(result['evidence']! as List<Object?>)) {
          invalid.add('$name: $item missing failure evidence');
        }
      }

      for (final item in automatedItems) {
        if (items[item] case {
          'status': final status,
          'browsers': Map<String, Object?> browsers,
        } when browsers.length == gateBrowsers.length && browsers.keys.toSet().containsAll(gateBrowsers)) {
          final results = <String, GateResult>{};
          for (final browser in gateBrowsers) {
            if (browsers[browser] case {
              'status': final String status,
              'evidence': final List<Object?> evidence,
            } when {'pass', 'fail', 'not-run'}.contains(status) && evidence.every((entry) => entry is String)) {
              final unsupported = (browsers[browser] as Map)['unsupported'] == true;
              final result = GateResult(status, evidence.cast<String>(), unsupported: unsupported);
              results[browser] = result;
              if (!_hasEvidence(evidence)) invalid.add('$name: $item/$browser missing evidence');
              if (unsupported && status != 'not-run') invalid.add('$name: $item/$browser invalid unsupported marker');
              if (status == 'not-run' && !_unsupportedEmulation(result)) {
                unavailable.add('$name: $item/$browser did not run');
              }
            } else {
              invalid.add('$name: $item/$browser invalid browser result');
            }
          }
          final aggregate = _gateItemStatus(results.values);
          if (results.length != gateBrowsers.length || status != aggregate) {
            invalid.add('$name: $item inconsistent browser results');
          }
          if (aggregate == 'not-run') unavailable.add('$name: $item did not run');
          automated[item] = (status: aggregate, browsers: results);
        } else {
          invalid.add('$name: $item invalid automated result');
        }
      }

      return GateRecordAssessment._(
        name: name,
        declaredVerdict: verdict,
        automated: automated,
        manual: manual,
        invalid: invalid,
        unavailable: unavailable,
      );
    }
    return GateRecordAssessment._(name: name, invalid: ['$name: invalid gate record']);
  }

  final String name;
  final String? declaredVerdict;
  final Map<String, ({String status, Map<String, GateResult> browsers})> automated;
  final Map<String, String> manual;
  final List<String> invalid;
  final List<String> unavailable;

  bool get _automatedPass =>
      automated.length == automatedItems.length && automated.values.every((item) => item.status == 'pass');
  bool get hasConsistentVerdict => declaredVerdict == (_automatedPass ? 'pass' : 'fail');
  bool get qualified => invalid.isEmpty && declaredVerdict == 'pass' && _automatedPass;
  bool get supported => qualified && manual.values.every((status) => status == 'pass');

  Set<String> get failedItems => {
    for (final item in manual.entries)
      if (item.value == 'fail') item.key,
    for (final item in automated.entries)
      if (item.value.status == 'fail') item.key,
  };
}

bool _unsupportedEmulation(GateResult result) => result.unsupported && _hasEvidence(result.evidence);

bool _hasEvidence(Iterable<Object?> entries) => entries.any((entry) => entry is String && entry.trim().isNotEmpty);

String encodeRecord(Map<String, Object?> record) => '${const JsonEncoder.withIndent('  ').convert(record)}\n';
