import 'package:matcher/matcher.dart';

import '../validator.dart';

/// Returns a matcher that validates a trellis template source string.
Matcher isValidTemplate({TemplateValidator? validator}) => _ValidTemplateMatcher(validator ?? TemplateValidator());

final class _ValidTemplateMatcher extends Matcher {
  final TemplateValidator _validator;

  const _ValidTemplateMatcher(this._validator);

  @override
  Description describe(Description description) => description.add('a valid trellis template');

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! String) {
      matchState[_mismatchKey] = 'was not a String';
      return false;
    }

    final errors = _validator.validate(item);
    if (errors.isEmpty) {
      return true;
    }

    matchState[_mismatchKey] = errors;
    return false;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    final mismatch = matchState[_mismatchKey];
    if (mismatch is String) {
      return mismatchDescription.add(mismatch);
    }

    final errors = mismatch as List<ValidationError>? ?? const <ValidationError>[];
    for (final error in errors) {
      mismatchDescription.add(
        '[line ${error.line ?? 0}] ${error.severity.name}: ${error.message}'
        '${error.attribute != null ? ' (${error.attribute})' : ''}; ',
      );
    }
    return mismatchDescription;
  }
}

const _mismatchKey = #validTemplateMismatch;
