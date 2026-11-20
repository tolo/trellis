import 'dart:io';

import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';

void main() {
  test('suite payload stays within 30,000 bytes gzipped', () {
    final gzip = GZipCodec(level: 9);
    expect(
      trellisUiAssetPaths,
      containsAll(['/trellis-ui/trellis-ui.css', '/trellis-ui/trellis-ui.js', '/trellis-ui/htmx-indicator.css']),
    );
    final sizes = {for (final path in trellisUiAssetPaths) path: gzip.encode(trellisUiRespond(path)!.body).length};
    final total = sizes.values.reduce((a, b) => a + b);
    print('Suite payload gzip level 9: $total bytes (${sizes.entries.map((e) => '${e.key} ${e.value}').join(', ')})');
    expect(total, lessThanOrEqualTo(30000), reason: 'Suite payload is $total bytes gzipped across separate responses');
  });
}
