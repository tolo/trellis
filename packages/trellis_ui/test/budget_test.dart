import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/bundle.dart';

void main() {
  test('owned behaviour JS stays within the release gate', () {
    final files = sourceFiles(Directory('assets/js'), '.js');
    expect(files, isNotEmpty);
    final lines = files
        .expand((file) {
          final withoutBlockComments = file.readAsStringSync().replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
          return withoutBlockComments.split('\n').map((line) => line.trim());
        })
        .where((line) => line.isNotEmpty && !line.startsWith('//'));
    expect(lines.length, lessThanOrEqualTo(700));
    expect(bundleScript(Directory.current), startsWith('(function () {\n"use strict";'));
  });
}
