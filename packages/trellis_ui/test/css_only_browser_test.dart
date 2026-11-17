import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../../../tool/ui_gate/driver.dart';
import '../tool/src/gallery.dart';

void main() {
  late HttpServer server;
  late ChromeDriver driver;
  setUp(() async {
    server = await shelf_io.serve(galleryHandler(Directory.current), InternetAddress.loopbackIPv4, 0);
    driver = await ChromeDriver.launch();
  });
  tearDown(() async {
    await driver.close();
    await server.close(force: true);
  });
  Future<void> open(String component, int width) async {
    await driver.viewport(width, 900);
    await driver.open(Uri.parse('http://127.0.0.1:${server.port}/components/$component'));
  }

  test('layout primitives lay out in DOM order at 390, 768 and 1440', () async {
    final gridColumns = <int, int>{};
    for (final width in [390, 768, 1440]) {
      for (final component in ['stack', 'cluster', 'grid', 'container']) {
        await open(component, width);
        final geometry =
            await driver.evaluate(r'''(() => {
          const layout=document.querySelector('#layout'), boxes=[...layout.children].map(e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height}}), s=getComputedStyle(layout), r=layout.getBoundingClientRect();
          const side=document.querySelector('#sidebar');
          return {boxes,gap:parseFloat(s.gap),width:r.width,x:r.x,padding:parseFloat(s.paddingInlineStart),columns:s.gridTemplateColumns.split(' ').length,minimum:parseFloat(s.getPropertyValue('--trellis-grid-minimum'))*16,overflow:document.documentElement.scrollWidth>document.documentElement.clientWidth,sidebar:side?[...side.children].map(e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height}}):null};
        })()''')
                as Map;
        expect(geometry['overflow'], false, reason: '$component at $width');
        final boxes = (geometry['boxes'] as List).cast<Map<String, dynamic>>();
        for (var i = 1; i < boxes.length; i++) {
          final a = boxes[i - 1], b = boxes[i];
          expect(
            (b['y'] as num) > (a['y'] as num) ||
                ((b['y'] as num) - (a['y'] as num)).abs() < 1 && (b['x'] as num) > (a['x'] as num),
            true,
            reason: '$component DOM order at $width',
          );
        }
        if (component == 'stack') {
          expect(boxes.map((e) => e['x']).toSet(), hasLength(1));
          expect(
            (boxes[1]['y'] as num) - (boxes[0]['y'] as num) - (boxes[0]['h'] as num),
            closeTo(geometry['gap'] as num, 1),
          );
        }
        if (component == 'cluster' && width == 390) expect(boxes.map((e) => e['y']).toSet().length, greaterThan(1));
        if (component == 'grid') {
          gridColumns[width] = geometry['columns'] as int;
          for (final box in boxes) {
            expect(box['w'], closeTo(boxes.first['w'] as num, 1));
          }
          for (final box in boxes) {
            expect(box['w'] as num, greaterThanOrEqualTo(geometry['minimum'] as num));
          }
        }
        if (component == 'container') {
          expect(geometry['width'] as num, lessThanOrEqualTo(640));
          expect(geometry['x'] as num, closeTo((width - (geometry['width'] as num)) / 2, 1));
          expect(geometry['padding'], 16);
          final side = (geometry['sidebar'] as List).cast<Map<String, dynamic>>();
          if (width == 1440) expect(side[0]['y'], closeTo(side[1]['y'] as num, 1));
          if (width == 390) expect(side[0]['y'] as num, lessThan(side[1]['y'] as num));
        }
      }
    }
    expect(gridColumns[1440], greaterThan(gridColumns[390]!));
  });

  test('touch targets hold 24 px and 44 px and coarse inputs use 16 px', () async {
    for (final coarse in [false, true]) {
      for (final name in [
        'button',
        'input',
        'textarea',
        'field',
        'native-select',
        'checkbox',
        'radio',
        'switch',
        'badge',
        'card',
        'alert',
        'table',
        'pagination',
        'breadcrumb',
        'separator',
      ]) {
        await open(name, 390);
        expect(await driver.media(coarse: coarse), true, reason: 'pointer condition must read back');
        final issues = await driver.evaluate('''(() => {const issues=[];
          for(const e of document.querySelectorAll('#component :is(button,input,select,textarea,a[href],[tabindex])')) {
            const r=e.getBoundingClientRect(),s=getComputedStyle(e);if(!r.width||!r.height)continue;
            if(Math.min(r.width,r.height)<${coarse ? 44 : 24}-.1)issues.push((e.id||e.className)+' '+r.width+'x'+r.height);
            if($coarse&&e.matches('input,select,textarea')&&parseFloat(s.fontSize)<16)issues.push(e.id+' font '+s.fontSize);
          }return issues;})()''');
        expect(issues, isEmpty, reason: '$name coarse=$coarse');
      }
    }
  });

  test('pagination retains a visible next label on mobile', () async {
    await open('pagination', 390);
    expect(
      await driver.evaluate(
        "(() => {const e=document.querySelector('.trellis-pagination-next-text'),r=e.getBoundingClientRect();return r.width>0 && r.height>0 && e.textContent.trim()==='Next'})()",
      ),
      true,
    );
  });

  test('card description sits below its title when the action slot is empty', () async {
    await open('card', 1440);
    final boxes =
        await driver.evaluate(
              "(() => {const a=document.querySelector('.trellis-card-title').getBoundingClientRect(),b=document.querySelector('.trellis-card-description').getBoundingClientRect();return {title:a.toJSON(),description:b.toJSON()}})()",
            )
            as Map;
    final title = boxes['title'] as Map, description = boxes['description'] as Map;
    expect(description['x'], closeTo(title['x'] as num, 1));
    expect(description['y'] as num, greaterThanOrEqualTo(title['bottom'] as num));
  });

  test('navigation links inherit their suite colour in both modes', () async {
    for (final name in ['breadcrumb', 'pagination']) {
      for (final dark in [false, true]) {
        await open(name, 390);
        await driver.evaluate("document.documentElement.classList.toggle('dark', $dark)");
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final colors =
            await driver.evaluate(
                  "(() => {return [...document.querySelectorAll('#component a')].map(e=>({actual:getComputedStyle(e).color,expected:getComputedStyle(e.parentElement).color}))})()",
                )
                as List;
        expect(colors, isNotEmpty);
        for (final raw in colors) {
          final color = raw as Map;
          expect(color['actual'], color['expected'], reason: '$name dark=$dark');
        }
      }
    }
  });

  test('native control paint matches vega inside the hit box', () async {
    for (final name in ['checkbox', 'radio', 'switch']) {
      await open(name, 768);
      final paint =
          await driver.evaluate(
                "(() => {const s=getComputedStyle(document.querySelector('#primary'),'::before'),border=s.boxSizing==='border-box'?0:parseFloat(s.borderLeftWidth)+parseFloat(s.borderRightWidth);return {width:parseFloat(s.width)+border,height:parseFloat(s.height)+border}})()",
              )
              as Map;
      expect(paint['width'], closeTo(name == 'switch' ? 32 : 16, .1), reason: name);
      expect(paint['height'], closeTo(name == 'switch' ? 18.4 : 16, .1), reason: name);
    }
  });

  test('forced colours keep focus and checked state visible', () async {
    for (final name in ['checkbox', 'radio', 'switch', 'input', 'native-select', 'button']) {
      await open(name, 768);
      expect(await driver.media(forcedColors: true), true, reason: 'forced colours must read back');
      final selector = name == 'button' ? '.trellis-button' : '#primary';
      await driver.evaluate("document.querySelector('#before').focus()");
      await driver.press('Tab');
      final focus = await driver.evaluate(
        "(() => {const e=document.querySelector('$selector'),s=getComputedStyle(e);return document.activeElement===e && s.outlineStyle!=='none' && parseFloat(s.outlineWidth)>0})()",
      );
      expect(focus, true, reason: name);
      if (['checkbox', 'radio', 'switch'].contains(name)) {
        const paint =
            "(() => {const s=getComputedStyle(document.querySelector('#primary'),'::before');return [s.borderColor,s.borderWidth,s.backgroundColor]})()";
        final before = await driver.evaluate(paint);
        await driver.press(' ');
        expect(await driver.evaluate("document.querySelector('#primary').checked"), true);
        expect(await driver.evaluate(paint), isNot(before), reason: '$name checked paint survives forced colours');
      }
    }
  });
}
