// Self-contained trellis example — no external dependencies.
//
// Run: dart run example/example.dart

import 'package:trellis/trellis.dart';

void main() {
  final engine = Trellis(
    loader: MapLoader({}),
    filters: {'currency': (v) => '\$${(v as num).toStringAsFixed(2)}'},
  );

  // --- Template featuring v0.2 attributes ---
  const template = '''
<html>
<body>
  <h1 tl:text="\${title}">Page Title</h1>

  <!-- Conditional -->
  <p tl:if="\${user}" tl:text="'Welcome, ' + \${user.name | upper} + '!'">
    Welcome, Guest!
  </p>

  <!-- Switch -->
  <div tl:switch="\${role}">
    <span tl:case="admin">Admin panel</span>
    <span tl:case="user">Dashboard</span>
    <span tl:case="*">Guest view</span>
  </div>

  <!-- Iteration with classappend -->
  <ul tl:fragment="itemList">
    <li tl:each="item : \${items}"
        tl:text="\${item.name} + ' — ' + \${item.price | currency}"
        tl:classappend="\${itemStat.odd} ? 'alt' : ''">
      placeholder
    </li>
  </ul>

  <!-- Parameterized fragment -->
  <div tl:fragment="card(heading, body)">
    <h2 tl:text="\${heading}">Heading</h2>
    <p tl:text="\${body}">Body</p>
  </div>

  <!-- Include the parameterized fragment with arguments -->
  <div tl:insert="card('Features', 'Fragment-first design')">card slot</div>

  <!-- Named fragment for renderFragments demo -->
  <footer tl:fragment="footer" tl:text="\${title}">Footer</footer>
</body>
</html>
''';

  final context = {
    'title': 'Trellis v0.2 Demo',
    'user': {'name': 'Alice'},
    'role': 'admin',
    'items': [
      {'name': 'Widget', 'price': 9.99},
      {'name': 'Gadget', 'price': 24.5},
      {'name': 'Gizmo', 'price': 3},
    ],
  };

  // Full page render
  print('=== Full Page ===');
  print(engine.render(template, context));

  // Fragment render (HTMX partial)
  print('\n=== Fragment: itemList ===');
  print(engine.renderFragment(template, fragment: 'itemList', context: context));

  // Multi-fragment render (HTMX OOB swap)
  print('\n=== renderFragments: itemList + footer ===');
  print(engine.renderFragments(
    template,
    fragments: ['itemList', 'footer'],
    context: context,
  ));

  // Standalone expression evaluator
  final evaluator = ExpressionEvaluator();
  print('\n=== ExpressionEvaluator ===');
  print(evaluator.evaluate(r'${x} + ${y}', {'x': 10, 'y': 32})); // 42
}
