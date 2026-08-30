/// Shared resolution of front matter `date:` values for feeds and the sitemap.
library;

final _dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _timeSeparator = RegExp('[Tt ]');
final _explicitZone = RegExp(r'(?:[zZ]|[+-]\d{2}(?::?\d{2})?)$');

/// Resolves a front matter `date:` value to a UTC [DateTime], or `null` when
/// [value] is absent or unparseable.
///
/// A date-only value (`2026-01-01`) names a calendar day, not an instant, so it
/// is anchored at UTC midnight rather than at the build machine's midnight.
/// `DateTime.parse` would read it as local time, which made the same content
/// emit a different `<updated>`/`<pubDate>` on every timezone — `2025-12-31T23:00:00Z`
/// on a CET laptop against `2026-01-01T00:00:00Z` on a UTC runner. The blog
/// scaffold ships date-only values, so that was the default path.
///
/// Values with an explicit offset are parsed as written. A zone-less date-time
/// names UTC calendar fields, matching the date-only rule, so identical source
/// produces identical feed and sitemap output on every build machine.
DateTime? resolveFrontMatterDate(Object? value) {
  if (value is DateTime) return value.toUtc();
  if (value is! String) return null;

  final text = value.trim();
  if (_dateOnly.hasMatch(text)) {
    // Parse first, then re-anchor the calendar fields in UTC. Parsing keeps
    // DateTime.parse's existing out-of-range rollover (`2026-13-45` becomes
    // 2027-02-14) rather than changing validation alongside the timezone fix.
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  final separator = text.indexOf(_timeSeparator);
  if (separator >= 0 && !_explicitZone.hasMatch(text.substring(separator + 1))) {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  return parsed.toUtc();
}
