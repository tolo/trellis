import 'package:trellis_site/trellis_site.dart';

/// Returns the warning for a theme that requires a newer Trellis version.
String? themeCompatibilityWarning(ThemeManifest manifest) {
  final minimumVersion = manifest.minTrellisVersion;
  if (minimumVersion == null || !_isVersionLessThan(siteVersion, minimumVersion)) {
    return null;
  }
  return 'Warning: Theme requires trellis_site >=$minimumVersion '
      'but installed version is $siteVersion. '
      'Some features may not work correctly.';
}

bool _isVersionLessThan(String installed, String required) {
  final installedParts = installed.split('.').map(int.tryParse).toList();
  final requiredParts = required.split('.').map(int.tryParse).toList();
  for (var i = 0; i < 3; i++) {
    final installedPart = i < installedParts.length ? (installedParts[i] ?? 0) : 0;
    final requiredPart = i < requiredParts.length ? (requiredParts[i] ?? 0) : 0;
    if (installedPart < requiredPart) return true;
    if (installedPart > requiredPart) return false;
  }
  return false;
}
