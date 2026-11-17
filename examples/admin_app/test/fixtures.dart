import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart';
import 'package:test/test.dart';

const validContact = {
  'name': 'A Aaron Example',
  'email': 'aaron@example.test',
  'company': 'acme',
  'q': 'Acme Studio',
  'status': 'active',
};

const suiteAssets = {
  '/trellis-ui/trellis-ui.css': 'text/css',
  '/trellis-ui/trellis-ui.js': 'text/javascript',
  '/trellis-ui/htmx-indicator.css': 'text/css',
};

const htmxAsset = '/js/htmx.min.js';

Map<String, String> mutationHeaders(String cookie, String page) {
  final hxHeaders = parse(page).body!.attributes['hx-headers']!;
  final token = (jsonDecode(hxHeaders) as Map<String, dynamic>)['X-CSRF-Token'] as String;
  return {
    'cookie': cookie.split(';').first,
    'x-csrf-token': token,
    'content-type': 'application/x-www-form-urlencoded',
    'hx-request': 'true',
  };
}

String formBody(Map<String, String> fields) => Uri(queryParameters: fields).query;

void expectStrictPolicy(String? policy) {
  expect(policy, isNotNull);
  final directives = policy!.split('; ').map((directive) => directive.split(' '));
  expect(
    directives,
    containsAll([
      ['default-src', "'self'"],
      ['script-src', "'self'"],
      ['style-src', "'self'"],
    ]),
  );
  for (final directive in directives) {
    expect(directive.skip(1), everyElement(isIn(["'self'", "'none'", 'data:'])), reason: directive.join(' '));
  }
}

Future<void> copyAppFiles(Directory destination) async {
  for (final folder in ['templates', 'static']) {
    final source = Directory(folder);
    await Directory('${destination.path}/$folder').create(recursive: true);
    await for (final file in source.list(recursive: true).where((entry) => entry is File).cast<File>()) {
      final target = File('${destination.path}/${file.path}');
      await target.parent.create(recursive: true);
      await file.copy(target.path);
    }
  }
}
