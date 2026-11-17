import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:trellis_cli/src/templates/htmx_asset.dart';

void expectStrictScaffold(
  Map<String, String> files, {
  required bool cdn,
  required String staticRoot,
  required String layout,
  required String server,
  required bool csrf,
}) {
  final html = files[layout]!;
  expect(html, contains(htmxConfigMeta));
  expect(html, contains('"includeIndicatorStyles":false'));
  expect(html.indexOf('name="htmx-config"'), lessThan(html.indexOf('<script')));
  final htmxPath = '$staticRoot/js/htmx.min.js';
  if (cdn) {
    expect(html, contains(htmxScriptTag()));
    expect(files, isNot(contains(htmxPath)));
    expect(files[server], contains('scriptSrc: "\'self\' $htmxCdnOrigin"'));
  } else {
    expect(html, contains('<script src="/js/htmx.min.js"></script>'));
    expect(html, isNot(contains('cdn.jsdelivr.net')));
    expect('sha384-${base64.encode(sha384.convert(utf8.encode(files[htmxPath]!)).bytes)}', htmxSriHash);
    expect(files[server], isNot(contains('cdn.jsdelivr.net')));
  }
  expect(files[server], contains('CspBuilder.strict('));
  expect(files[server], isNot(contains('ws:')));
  expect(files['$staticRoot/styles.css'], contains(htmxIndicatorCss));
  expect(files['$staticRoot/styles.css'], contains('.htmx-indicator { opacity: 0; }'));
  expect(
    files['$staticRoot/styles.css'],
    contains('.htmx-request .htmx-indicator, .htmx-request.htmx-indicator { opacity: 1; }'),
  );
  if (csrf) {
    expect(html, contains('<script src="/js/csrf.js"></script>'));
    expect(files['$staticRoot/js/csrf.js'], csrfScript);
  }
  final pages = files.entries.where((entry) => entry.key.endsWith('.html'));
  expect(pages, isNotEmpty);
  for (final entry in files.entries) {
    expect(entry.value, isNot(contains("'unsafe-inline'")), reason: entry.key);
    if (!entry.key.endsWith('.html')) continue;
    // Vendor JavaScript contains inert HTML strings; inspect the markup that
    // the browser parses, while the browser proof covers runtime injection.
    expect(
      RegExp(r'<script(?![^>]*\bsrc=)[^>]*>\s*\S', caseSensitive: false).hasMatch(entry.value),
      isFalse,
      reason: entry.key,
    );
    expect(
      RegExp(r'<style\b|\sstyle\s*=|\son[a-z]+\s*=', caseSensitive: false).hasMatch(entry.value),
      isFalse,
      reason: entry.key,
    );
  }
}
